close all;
clear all;
clc;
folder_path = 'E:\视频切片\A1-0';
file_list = dir(fullfile(folder_path, '*.jpg'));
path_save = 'E:\视频切片\';
ID = 'A1-0';
time_seconds = zeros(numel(file_list),1); % 新增一个数组用于存储时间信息
first_row_with_few_nonzeros = zeros(numel(file_list),1); % 新增一个数组用于存储每张图片中符合条件的行号
for K = 1:numel(file_list)
    [~, file_name, ~] = fileparts(file_list(K).name);
    time_str = regexp(file_name, '\d+', 'match');
    time_seconds(K) = str2double(time_str{end}) * (1/25); % 计算时间信息
    X = imread(fullfile(folder_path, file_list(K).name));
    X_1 = imcrop(X, [1170,250,60,515]);
    X_2 = rgb2gray(X_1);
    X_3 = imbinarize(X_2,0.66);
    X_4 = imfill(X_3,'holes');
    
    [m, n] = size(X_4); % 获取矩阵的大小
    r = m;
    
    % 查找第一行包含大于5个非零元素的行号
    for row = 1:size(X_4, 1)
        if sum(X_4(row, :)) >= 5
            first_row_with_few_nonzeros(K) = row;
            break;
        end
    end
end
% 计算比例尺并生成最终矩阵
pixel_h = abs(r - first_row_with_few_nonzeros) * 2; % 比例尺
M = [pixel_h, zeros(length(pixel_h), 2)]; % 新增两列用于概率和时间
gailv = zeros(length(pixel_h),1);
for i = 1:length(M)
    gailv(i) = sum(sum(M(i, 1) >= M(i, 1))) / length(M);
end
M(:, 2) = gailv;
M(:, 3) = time_seconds; % 将时间信息添加到第三列
writematrix(M, fullfile(path_save, [num2str(ID), '.txt']));
disp('代码运行完成。');
% 绘图部分
figure;
plot(M(:, 3), M(:, 1), '-o'); % 第三列为横轴，第一列为纵轴
xlabel('时间 (秒)');
ylabel('比例尺 (mm/像素)');
title('比例尺随时间变化图');
grid on;