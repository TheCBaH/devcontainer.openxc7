#!/bin/sh
set -eu
export PATH=/opt/openxc7/bin:$PATH
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
cat > counter.v <<'EOF'
module counter(input clk, output led);
reg [25:0] value = 0;
always @(posedge clk) value <= value + 1;
assign led = value[25];
endmodule
EOF
yosys -Q -p 'synth_xilinx -flatten -abc9 -arch xc7 -top counter; write_json counter.json' counter.v
yosys -Q -p 'read_slang counter.v; synth_xilinx -flatten -abc9 -arch xc7 -top counter; write_json slang.json'
for package in cpg236 csg324; do
    case "$package" in
        cpg236) clk=W5; led=U16 ;;
        csg324) clk=E3; led=H5 ;;
    esac
    cat > counter.xdc <<EOF
set_property PACKAGE_PIN $clk [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property PACKAGE_PIN $led [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
create_clock -period 10.0 [get_ports clk]
EOF
    nextpnr-himbaechel --device "xc7a35t$package-1" \
        --chipdb /opt/openxc7/share/chipdb/xc7a50t.bin \
        --json counter.json -o xdc=counter.xdc -o fasm=counter.fasm \
        -o delay-matrix=/opt/openxc7/share/chipdb/xc7a50t.delay --freq 100
    fpga-as --prjxray_db_path=/opt/openxc7/share/nextpnr/prjxray-db/artix7 \
        --part "xc7a35t$package-1" counter.fasm > counter.bit
    test "$(wc -c < counter.bit)" -gt 2000000
    echo "PASS xc7a35t$package-1"
done
