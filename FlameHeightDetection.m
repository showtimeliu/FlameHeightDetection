clearvars -except pdVideoRGB;
close all; 

f1 = figure('Position', [200, 100, 1000, 800]); 

bPreload = 1; % 如第一次运行需要加载背景图（1或者true）

strFolder = 'C:\Users\showt\OneDrive\Taobao MATLAB\20250127 Flame height\火焰高度侧面视频\B\';
strFileID = 'B4-0'; 
strVideo = sprintf('%s%s.mp4', strFolder, strFileID); 

strSaveFolder = sprintf('%s%s\\', strFolder, strFileID); 
mkdir(strSaveFolder); 

% load video and video parameters
v = VideoReader(strVideo); 
dFrameRate = v.FrameRate; 
nFrameTotal = v.NumFrames; 

% pdTime = ((1:nFrameTotal) - 1)' / dFrameRate; 

% parameters
dTimeReso = 1.0;        % temporal resolution in sec 
dEnhanceContrast = [0.0, 0.0, 0.0; 0.6, 0.6, 0.6];

nFrameReso = round(dTimeReso / (1/dFrameRate)); 

% nCropX1 = 851;
% nCropX2 = 1000;

%% pre-load timely-sparse frames to calculate background image

if bPreload
    

    % 
    pnFrames = floor(linspace(1, nFrameTotal, 100));  
    % pdVideoRGB = zeros(v.Height, nCropX2-nCropX1+1, 3, length(pnFrames));
    pdVideoRGB = zeros(v.Height, v.Width, 3, length(pnFrames));

    for ii = 1 : length(pnFrames)
        nFrame = pnFrames(ii);
        dFrameTime = (nFrame - 1) / dFrameRate;

        if mod(ii, 5) == 0
            fprintf('(%d/%d) preloading frame %d...\n', ii, length(pnFrames), nFrame);
        end

        v.CurrentTime = dFrameTime;
        pdVideoRGB(:, :, :, ii) = readFrame(v); 

        % crop frame 
        % pdFrameRGB = readFrame(v);
        % pdFrameCropped = pdFrameRGB(:, nCropX1:nCropX2, :);
        % pdVideoRGB(:, :, :, ii) = pdFrameCropped;

        % figure(f1);
        %
        % sp1 = subplot(1, 2, 1);
        % imagesc(pdFrameCropped); colormap(gray);
        % ax = gca;
        % ax.DataAspectRatio = [1, 1, 1];
        % title(nFrame);


        clear pdFrameRGB pdFrameCropped;

    end
    pdVideoRGB = pdVideoRGB / 255; 

end % if bPreload

pdBackgroundRGBFullWidth = mean(pdVideoRGB, 4); 

%% set up the regions in the background image 

bQuestDlgRemoveRegion = true; 

% crop the image and only keep a narrow flame region 
figure(f1); 
image(imadjust(pdBackgroundRGBFullWidth, dEnhanceContrast/2, [])); 
ax = gca;
ax.DataAspectRatio = [1, 1, 1];
sgtitle(sprintf('Select the left/right margins of the ROI...'));

uiwait(msgbox('Please select the left/right margins of the ROI...', 'Image ROI'));

nClick1 = round(custom_ginput(1, 'r'));
hold on; xline(nClick1(1), 'w'); 
nClick2 = round(custom_ginput(1, 'r')); 
hold on; xline(nClick2(1), 'w'); 
hold off; 

nCropX1 = min([nClick1(1), nClick2(1)]);
nCropX2 = max([nClick1(1), nClick2(1)]);

pdBackgroundRGB = pdBackgroundRGBFullWidth(:, nCropX1 : nCropX2, :); 
clear nClick1 nClick2 pdBackgroundRGBFullWidth; 

% locate the center divider by clicking the object on background image 
figure(f1); 
sp2 = subplot(1, 5, 2);
image(imadjust(pdBackgroundRGB, dEnhanceContrast/2, []));
ax = gca;
ax.DataAspectRatio = [1, 1, 1];
sgtitle(sprintf('Set up the regions in the background image...'));

% define the physical height 
uiwait(msgbox('Please draw a vertical line to define the 1st divider (20 cm)...', 'Define 20 cm '));

hLine = drawline; 
pos = hLine.Position; 

dRefDividerY1 = pos(1, 2); 
dRefDividerY2 = pos(2, 2); 
dBaseHeight = max([dRefDividerY1, dRefDividerY2]); 

strPrompt = {'Enter the physical length of the line marked (in cm):'}; 
answer = inputdlg(strPrompt, 'Length of reference divider', 1, {'20'}); 
dRefDividerHeight = str2double(answer{1});

dPixelHeightCM = dRefDividerHeight / abs(dRefDividerY1 - dRefDividerY2); 
clear strPrompt answer; 

subplot(sp2); 
hold on; yline(dBaseHeight, 'w--', 'LineWidth', 2); 
hold off; 
drawnow; 

% define the position of reference divider and divide the image into subsets 
uiwait(msgbox('Please locate and click on the edge of the divider...', 'Locate divider')); 
nDivider = round(custom_ginput(1, 'g')); 
% nDivider = [80, 600]; 

subplot(sp2); 
hold on; yline(nDivider(2), 'w');  
hold on; xline(nDivider(1), 'w'); 
hold off; 

% remove bright flames in the background to improve detection accuracy
uiwait(msgbox('Now please remove the unwanted flames in the background image...', 'Locate divider')); 

nRegionID = 1; 
choiceInitial = questdlg(sprintf('Please circle the unwanted flame in the background (Region %d)', nRegionID), ...
    sprintf('Circle Region %d...', nRegionID), ...
    'Yes', 'No', 'No'); % 'No' is the default option\

switch choiceInitial
    case 'Yes'
        figure(f1);
        subplot(sp2);
        hFreehand = drawfreehand;
        pbMask = ~createMask(hFreehand);
        pdBackgroundRGB = pdBackgroundRGB .* repmat(pbMask, [1, 1, 3]);

        image(imadjust(pdBackgroundRGB, dEnhanceContrast/2, []));
        ax = gca;
        ax.DataAspectRatio = [1, 1, 1];

        drawnow;

        while bQuestDlgRemoveRegion == true
            nRegionID = nRegionID + 1;

            choiceNext = questdlg(sprintf('Circle the NEXT unwanted flame? (Region %d)', nRegionID), ...
                sprintf('Circle Region %d...', nRegionID), ...
                'Yes', 'No', 'No'); % 'No' is the default option

            switch choiceNext
                case 'Yes'
                    figure(f1);
                    subplot(sp2);
                    hFreehand = drawfreehand;
                    pbMask = ~createMask(hFreehand);
                    pdBackgroundRGB = pdBackgroundRGB .* repmat(pbMask, [1, 1, 3]);

                    image(imadjust(pdBackgroundRGB, dEnhanceContrast/2, []));
                    ax = gca;
                    ax.DataAspectRatio = [1, 1, 1];

                    drawnow;

                case 'No'
                    bQuestDlgRemoveRegion = false;
            end
            
        end % while bQuestDlgRemoveRegion == true

    case 'No'
        bQuestDlgRemoveRegion = false;

end

uiwait(msgbox('You have removed all unwanted regions in the background image.', 'Completed')); 

figure(f1); 
saveas(gcf, sprintf('%s%s_Background.png', strSaveFolder, strFileID), 'png'); 

%% process each frame 
% pdVideoNoBg = pdVideoRGB - repmat(pdBackgroundRGB, [1, 1, 1, size(pdVideoRGB, 4)]); 

pnFrames = 1 : nFrameReso : nFrameTotal; 
pdTime = (pnFrames - 1)' / dFrameRate;  

% allocate arrays for detection results 
pdApex1_X = nan(length(pnFrames), 1);
pdApex1_Y = nan(length(pnFrames), 1);
pdApex1_Height = nan(length(pnFrames), 1);

pdApex2_X = nan(length(pnFrames), 1);
pdApex2_Y = nan(length(pnFrames), 1);
pdApex2_Height = nan(length(pnFrames), 1);

vWriter = VideoWriter(sprintf('%s%s_FlameTracing.avi', strSaveFolder, strFileID)); 
vWriter.FrameRate = 5; 
open(vWriter); 

for ii = 1 : 1 : length(pnFrames)
    nFrame = pnFrames(ii);
    dFrameTime = pdTime(ii);

    v.CurrentTime = dFrameTime;
    pdFrameRGB = readFrame(v);

    pdFrameRGB = double(pdFrameRGB(:, nCropX1:nCropX2, :)) / 255;
    pdFrameNoBg = pdFrameRGB - pdBackgroundRGB; 

    pdI = rgb2gray(pdFrameNoBg); 

    % split the image into subsets based on the dividers 
    pdI1 = 0 * pdI; 
    pdI1(nDivider(2):end, 1:nDivider(1)) = pdI(nDivider(2):end, 1:nDivider(1)); 

    pdI2 = pdI; 
    pdI2(nDivider(2):end, 1:nDivider(1)) = 0; 

    % detect the apex of the flame of each subset
    [dApex1, pbBinary1] = detectFlameApex(pdI1, 0.1);
    [dApex2, pbBinary2] = detectFlameApex(pdI2, 0.1);


    if isnan(dApex1(1)) && ~isnan(dApex2(1))
        dApex1 = dApex2;
    end

    if ~isnan(dApex1(1)) && isnan(dApex2(1))
        dApex2 = dApex1;
    end

    % if the detected apex of the left flame is capped by the top of the 
    % lower left subset (pdI1), use the coordinates of the higher of the 
    % two apexes as the detection for the flames on both sides, as the
    % there should only be one flame in the higher region
    if ~isnan(dApex1(1)) && ~isnan(dApex2(1))
        if abs(dApex1(2) - nDivider(2)) < 3

            if dApex1(2) < dApex2(2) % left flame is HIGHER
                dApex2 = dApex1;
            else                    % right flame is HIGHER
                dApex1 = dApex2;
            end
        end
    end

    % save results into data arrays
    if length(dApex1) > 1
        pdApex1_X(ii) = dApex1(1);
        pdApex1_Y(ii) = dApex1(2);
        pdApex1_Height(ii) = abs(dApex1(2) - dBaseHeight) * dPixelHeightCM;
    end

    if length(dApex2) > 1
        pdApex2_X(ii) = dApex2(1);
        pdApex2_Y(ii) = dApex2(2);
        pdApex2_Height(ii) = abs(dApex2(2) - dBaseHeight) * dPixelHeightCM;
    end

    % display figures and plots 
    figure(f1);
    sgtitle([]); 

    sp1 = subplot(2, 5, [1, 6]);
    % imagesc(pdVideoRGB(:, :, ii), [0, 1]); colormap(gray);
    image(imadjust(pdFrameRGB,  dEnhanceContrast, []));
    if ~isnan(dApex1)
        hold on; plot(dApex1(1), dApex1(2), 'c*');
        hold off;
    end
    if ~isnan(dApex1)
        hold on; plot(dApex2(1), dApex2(2), 'y*');
        hold off;
    end
    hold on; yline(nDivider(2), 'w');
    hold on; xline(nDivider(1), 'w');
    hold on; yline(dBaseHeight, 'w--', 'LineWidth', 2); 
    hold off;
    ax = gca;
    ax.DataAspectRatio = [1, 1, 1];
    title('raw frame');

    % % sp2 = subplot(2, 5, [2, 7]);
    % image(imadjust(pdBackgroundRGB, dEnhanceContrast, []));
    % hold on; yline(nDivider(2), 'w');
    % hold on; xline(nDivider(1), 'w');
    % hold off;
    % ax = gca;
    % ax.DataAspectRatio = [1, 1, 1];
    % title(sprintf('background'));
    % 
    % sp3 = subplot(1, 5, 3);
    % image(imadjust(pdFrameNoBg, dEnhanceContrast, []));
    % % image(imadjust(pdDiffRGB, dEnhanceContrast, []));
    % if ~isnan(dApex1)
    %     hold on; plot(dApex1(1), dApex1(2), 'c*');
    %     hold off;
    % end
    % if ~isnan(dApex1)
    %     hold on; plot(dApex2(1), dApex2(2), 'm*');
    %     hold off;
    % end
    % hold on; yline(nDivider(2), 'w');
    % hold on; xline(nDivider(1), 'w');
    % hold off;
    % ax = gca;
    % ax.DataAspectRatio = [1, 1, 1];
    % title(sprintf('background removed frame %d', pnFrames(ii)));

    sp4 = subplot(2, 5, [2, 7]);
    imshowpair(pbBinary1, pbBinary2); 
    if ~isnan(dApex1)
        hold on; plot(dApex1(1), dApex1(2), 'c*');
        hold off;
    end
    if ~isnan(dApex1)
        hold on; plot(dApex2(1), dApex2(2), 'y*');
        hold off;
    end
    hold on; yline(nDivider(2), 'w');
    hold on; xline(nDivider(1), 'w');
    hold on; yline(dBaseHeight, 'w--', 'LineWidth', 2); 
    hold off;
    ax = gca;
    ax.DataAspectRatio = [1, 1, 1];
    title('binary');

    sp5 = subplot(2, 5, [8, 9, 10]); 
    p1 = plot(pdTime, pdApex1_Height); 
    hold on; p2 = plot(pdTime, pdApex2_Height); 
    hold off; 
    xlim([0, max(pdTime)]); ylim([0, size(pdI, 1) * dPixelHeightCM]); 
    grid on;
    xlabel('time, sec'); ylabel('flame height, cm'); 
    legend([p1, p2], {'Left flame', 'Right flame'}, 'Location', 'northwest'); 
    
    sgtitle(sprintf('Video %s.mp4, frame %d, time %0.2f sec', strFileID, pnFrames(ii), pdTime(ii)), ...
        'Interpreter', 'none'); 

    drawnow; 

    pdFrame = getframe(gcf); 
    writeVideo(vWriter, pdFrame); 

end

close(vWriter); 
disp('video saved.');

%% save mat and csv files

    % mat file 
VideoInfo = v; 
FlameDetection = struct; 

FlameDetection.BackgroundImage = pdBackgroundRGB; 
FlameDetection.ImageScaling.ReferenceDividerLine = hLine; 
FlameDetection.ImageScaling.ReferenceDividerHeightInCM = dRefDividerHeight;
FlameDetection.ImageScaling.BaseHeightInPixel = dBaseHeight; 
FlameDetection.ImageScaling.PixelHeightInCM = dPixelHeightCM; 
FlameDetection.ImageSubsetsBound.X = nDivider(1);
FlameDetection.ImageSubsetsBound.Y = nDivider(2);
FlameDetection.TimeInSec = pdTime; 
FlameDetection.TemporalResolutionInSec = dTimeReso; 

FlameDetection.FlameApex1.note = 'left flame';
FlameDetection.FlameApex1.Coor = [pdApex1_X; pdApex1_Y]; 
FlameDetection.FlameApex1.HeightInCM = pdApex1_Height;

FlameDetection.FlameApex2.note = 'right flame';
FlameDetection.FlameApex2.Coor = [pdApex2_X; pdApex2_Y]; 
FlameDetection.FlameApex2.HeightInCM = pdApex2_Height;

strSaveMat = sprintf('%s%s_Result.mat', strSaveFolder, strFileID); 
save(strSaveMat, 'FlameDetection', 'VideoInfo');


    % CSV file 
FlameCSV = struct;

FlameCSV.TimeInSec = pdTime; 
FlameCSV.Flame_1_HeightInCM = pdApex1_Height; 
FlameCSV.Flame_2_HeightInCM = pdApex2_Height; 

tableFlameCSV = struct2table(FlameCSV); 
strSaveCSV = sprintf('%s%s_Result.csv', strSaveFolder, strFileID); 
writetable(tableFlameCSV, strSaveCSV); 
    




%% FUNCTION: detectFlameApex
function [pdApexCoor, pbBinary] = detectFlameApex(pdImage, varargin)

pdImage = imfilter(pdImage, ones(3, 3)/(3*3), 'replicate'); 

if nargin == 1
    pbI = imbinarize(pdImage); 
end

if nargin > 1
    dThreshold = varargin{1}; 
    pbI = zeros(size(pdImage)); 
    pbI(pdImage > dThreshold) = 1; 
    pbI = logical(pbI); 
end

if nargin > 2
    error('Invalid input parameter!'); 
end


% pbI = imclose(pbI, strel('disk', 3));
pbI = bwareaopen(pbI, 30);

pbBinary = pbI; 
[pdY, pdX] = find(pbI); 
dApexY = min(pdY); 
pdApexX = pdX(pdY == dApexY); 
dApexX = median(pdApexX); 
pdApexCoor = [dApexX, dApexY]; 

end


%% FUNCTION: custom_ginput
function points = custom_ginput(n, cursorColor)
    if nargin < 1, n = 1; end
    if nargin < 2, cursorColor = 'r'; end  % Default cursor color: red

    fig = gcf;
    ax = gca;
    hold on;
    
    % Create a custom crosshair
    hLineX = plot(ax, NaN, NaN, cursorColor, 'LineWidth', 1);
    hLineY = plot(ax, NaN, NaN, cursorColor, 'LineWidth', 1);
    
    points = zeros(n, 2);
    count = 0;

    % Update crosshair on mouse move
    set(fig, 'WindowButtonMotionFcn', @updateCursor);
    
    % Capture clicks
    set(fig, 'WindowButtonDownFcn', @captureClick);
    
    % Wait for user input
    uiwait(fig);
    
    % Cleanup
    delete(hLineX);
    delete(hLineY);
    set(fig, 'WindowButtonMotionFcn', '');
    set(fig, 'WindowButtonDownFcn', '');

    function updateCursor(~, ~)
        pt = get(ax, 'CurrentPoint');
        x = pt(1, 1);
        y = pt(1, 2);
        
        xlim = get(ax, 'XLim');
        ylim = get(ax, 'YLim');
        
        set(hLineX, 'XData', xlim, 'YData', [y, y]);
        set(hLineY, 'XData', [x, x], 'YData', ylim);
    end

    function captureClick(~, ~)
        count = count + 1;
        pt = get(ax, 'CurrentPoint');
        points(count, :) = pt(1, 1:2);
        
        if count >= n
            uiresume(fig);
        end
    end
end


