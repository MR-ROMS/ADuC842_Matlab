s = serialport("COM4", 9600);
s.Timeout = 2;
fprintf("Waiting...\n");
pause(3);
for i = 1:20
    try
        b = read(s, 1, "uint8");
        fprintf("0x%02X\n", b);
    catch
        fprintf("(timeout)\n");
        break;
    end
end
delete(s);