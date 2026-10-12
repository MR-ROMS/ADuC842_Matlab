% Connect
s = serialport('COM4', 9600);
s.Timeout = 5;

% Read and display messages
while s.NumBytesAvailable > 0
    data = read(s, s.NumBytesAvailable, "uint8");
    fprintf('%s', char(data));
end

% Keep reading for 5 seconds
tic;
while toc < 5
    if s.NumBytesAvailable > 0
        data = read(s, s.NumBytesAvailable, "uint8");
        fprintf('%s', char(data));
    end
end

delete(s);