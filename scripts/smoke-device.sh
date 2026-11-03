#!/bin/sh
set -eu
settings=$1
. "$settings"
prefix=${OPENXC7_PREFIX:-/opt/openxc7}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
cat > counter.v <<'EOF'
module counter(input clk, output q);
reg [3:0] count = 0;
always @(posedge clk) count <= count + 1;
assign q = count[3];
endmodule
EOF
yosys -Q -p 'synth_xilinx -flatten -abc9 -arch xc7 -top counter; write_json counter.json' counter.v
cat > counter.xdc <<EOF
set_property PACKAGE_PIN $CLOCK_PIN [get_ports clk]
set_property PACKAGE_PIN $OUTPUT_PIN [get_ports q]
set_property IOSTANDARD $IOSTANDARD [get_ports clk]
set_property IOSTANDARD $IOSTANDARD [get_ports q]
create_clock -period 10.0 [get_ports clk]
EOF
nextpnr-himbaechel --device "$PART" --chipdb "$prefix/share/chipdb/$DEVICE.bin" \
    --json counter.json -o xdc=counter.xdc -o fasm=counter.fasm --freq 100 \
    -o "delay-matrix=$prefix/share/chipdb/$DEVICE.delay"
fpga-as --prjxray_db_path="$prefix/share/nextpnr/prjxray-db/$FAMILY" \
    --part "$PART" counter.fasm > counter.bit
test -s counter.bit
test -s "$prefix/share/chipdb/$DEVICE.delay"
echo "PASS $DEVICE $PART"
