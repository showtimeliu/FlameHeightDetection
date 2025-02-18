clear;clc

movName1 = 'C0254_1'; % Specify the video name
movdir = strcat(movName1,'.mp4');

obj = VideoReader(movdir); % Read the video
newfolder = movName1;
mkdir(newfolder); % Create a new folder

intercept = 1; % Screenshot interval
minute = 0; % Start time (minutes)
second = 0; % Start time (seconds)
tduration = 60; % Duration (seconds),��Ҫ�ֶ��޸�
ratio = 2; % Pixels/mm (modify according to calibration distance)��ע����1mm�м������ص�.60����3cm

second = minute * 60 + second; % Convert start time to seconds
tbegin = floor(second*obj.FrameRate) + 1; % Start frame
tend = tbegin +floor(tduration*obj.FrameRate) ; % End frame
num = 0; % Counter
shipingchang=1920;
shipingkuan=1080;


tic;
h = waitbar(0,'Capturing frames, please wait!');

for i = tbegin:intercept:tend
    str = ['Capturing frames...', num2str((i-tbegin)/(tend-tbegin+1)*100), '%'];
    waitbar((i-tbegin)/(tend-tbegin+1), h, str)
    
    num = num + 1;
    t(i) = (i-tbegin)/ceil(obj.frame);
    name = [movName1, '\', 'frame', num2str(num,'%04d'), '.jpg'];
    image = read(obj, i);
    imwrite(image, name, 'jpg', 'Quality', 100);
end

close(h);
toc;

%% Calculate flame height
gailv = 0;
tic;
h = waitbar(0,'Calculating flame height, please wait!');

for i = 1:num
    str = ['Calculating flame height...', num2str(i/num*100), '%'];
    waitbar(i/num, h, str)
    
    name = [movName1, '\', 'frame', num2str(i,'%04d'), '.jpg'];
    z = imread(name);
    G = 1 * z(1:shipingkuan, 1:shipingchang, 2);%��Ҫ������Ƶʵ�ʣ���*���Ӧ
    G = medfilt2(G, [3, 3]);
    threshold = graythresh(G);
    EDGEB = im2bw(G, threshold);
    EDGEB1 = EDGEB;
    [m, n] = size(EDGEB);
    nname = [movName1, '\', 'frameprec', num2str(i,'%04d'), '.jpg'];
    imwrite(EDGEB, nname, 'jpg');
    
    tempy = zeros(1, n);
    
    for k = 1:n
        up = 0;
        down = 0;
        
        for j = 1:m
            if EDGEB(j, k) ~= 0
                up = j;
                break
            end
        end
        
        for j = m:-1:1
            if EDGEB(j, k) > 0
                down = j;
                break
            end
        end
        
        tempy(k) = down - up;
    end
    
    gailv = EDGEB + gailv;
    [height1(i), t(i)] = max(tempy);
end

close(h);
toc;

%% Save flame height to Excel
xlsxdir = [movName1, '\', 'flameheight.xlsx'];
xlswrite(xlsxdir, 'H', 'sheet1', 'A1');%%�����Ϊmm��λ�Ļ���߶ȣ�ע��ƽ�����˲�
xlswrite(xlsxdir, 't', 'sheet1', 'B1');
xlswrite(xlsxdir, height1', 'sheet1', 'A2');
xlswrite(xlsxdir, t', 'sheet1', 'B2');

gailv = gailv / num;
[xx, yy] = size(gailv);
temp_gailv = imrotate(gailv, -1, 'bilinear', 'crop');
x = linspace(-yy/2/ratio, yy/2/ratio, shipingchang);
y = linspace((xx-1)/ratio, 0/ratio, shipingkuan);
k = 0;
j = 0;

for k = 1:yy
    up = xx;
    
    for j = 2:xx
        if temp_gailv(j-1, k) < 0.5 && temp_gailv(j, k) >= 0.5
            temp = j;
            up = min(up, temp);
            break
        end
    end
    
    tempyy(k) = xx - up;
end

height2 = max(tempyy)-min(tempyy(tempyy>0));
xlswrite(xlsxdir, 'H', 'sheet2', 'A1');
xlswrite(xlsxdir, height2', 'sheet2', 'A2');

axis([-shipingkuan/ratio shipingkuan/ratio 0 shipingchang/ratio]);
figure(1);
contourf(x, y, temp_gailv, 9);
axis tight;
axis equal;
colorbar;
colormap(jet);
shading interp;
caxis([0,1]);
xlim([-shipingkuan/ratio, shipingkuan/ratio]);
ylim([0, shipingchang/ratio]);
dname = [movName1, '\', 'interval_rate.jpg'];
jpgdir = dname;
saveas(gcf, jpgdir);

%% �������Ƶ��
    N=size(height1,2);
    height1=height1-mean(height1);
    fs=obj.frame;   %�����Ƶ��
    t=1/fs:1/fs:N/fs;  %����ʱ������
    Y=fft(height1,N);
    %������
    Pyy=Y.*conj(Y)/N;
    %���Ƶ������
    f=fs*(0:N/2)/N;
    Pyy1=Pyy(1:N/2+1);
    figure(2)
    plot(f,Pyy1);
    title('���������񵴵�Ƶ�����');
    xlabel('Ƶ��(Hz)');
    grid;
    dname=[movName1,'\','\','Ƶ��.jpg'];
    jpgdir=dname; %������Ҫ����ͼ����ļ���������֧��ai/bmp/emf/eps/fig/jpg/m/pbm/pcx/pgm/png/ppm/tif�� 
    saveas(gcf,jpgdir); %����ͼ�� 
%% 
%         save result.mat
    dname=[movName1,'\','result.mat'];
    save(dname);
