clc;
clear;
%Features that work: 
%-The Video getting processed in timely segments

%-Detection of people on the loaded frames, using a little modified version
%of centrioid tracking and HOG.

%-A semi working way to track the bounding boxes which are created.


%Sources and Partners used:
%ChatGPT was used mostly for code correction, and minor changes, such as
%the implementation of the distacnce threshold.

%What i tried is a variety of smaller improvements such as (preprocessing of
%the frame to reduce the impact of the uneven lightning, bbox color
%randomiser and to get the video to be played inside the figure box, but
%sadly i lacked time to work theese out to the extent where they are
%usable.

%Kristóf P., Zalán T., Benedek V. were my partners, whom i spent
%time chating on discord while writing the code, the base of our code is
%very similar with Papp Krisófs, because we started together

%I talked with Kinga H. about ways to store the location,color and a value
%for each generated bounding box, and then iterating through them before
%generating a brand new ID one (this was scrapped, i am removing bboxes
%that are not used)

vid = VideoReader('input_video.mp4');
hogDetector = peopleDetectorACF;
playbackSpeed = 3;

% Initialize a map to store person-color associations
personColorMap = containers.Map('KeyType', 'double', 'ValueType', 'any');
% Initialize a map to store person tracking history
personHistoryMap = containers.Map('KeyType', 'double', 'ValueType', 'any');

% Number of consecutive frames for a person to be considered 
consecutiveFramesThreshold = 200;


% Distance threshold for Nearest Neighbor matching
distanceThreshold = 30;

% Create a video player object
videoPlayer = vision.VideoPlayer;

% Loop through frames
while hasFrame(vid)
    frame = readFrame(vid);

    % Resize the frame to a fixed size if needed
    frame = imresize(frame, 0.5); % Adjust the size as needed

    % Detect people using sliding window ( I was happy to see it detects
    % all "human like" contours in the HOG plane. I really did not have an
    % idea how should a search function be implemented
    bbox = detect(hogDetector, frame);

    % Create a colormap of distinct colors
    numPeople = size(bbox, 1);
    colors = ["red", "green", "blue", "yellow", "magenta", "cyan", "white", "black"];

    % Process each person in the frame
    for j = 1:numPeople
        % Check if the person has been assigned a color
        if personColorMap.isKey(j)
            % Retrieve the color from the map
            color = personColorMap(j);
        else
            % Assign a color if not already assigned
            color = colors(mod(j, numel(colors)) + 1);
            % Store the color in the map
            personColorMap(j) = color;
        end


        

        % Display bounding box with label, assigned color, and Doxa
        label = sprintf('Person: %d', j); % Assuming Doxa is the index
        frame = insertObjectAnnotation(frame, 'rectangle', bbox(j, :), label, 'Color', color);
    end

    % Update person tracking using Nearest Neighbor matching
    persistentPersons = [];
    for k = 1:length(persistentPersons)
        % Find the nearest neighbor for each persistent person
        distances = vecnorm(bbox - personHistoryMap(persistentPersons(k)).LastBoundingBox, 2, 2);
        [minDist, minIdx] = min(distances);

        % If the nearest neighbor is within the distance threshold, update the track
        if minDist <= distanceThreshold
            personHistoryMap(persistentPersons(k)).LastBoundingBox = bbox(minIdx, :);
            personHistoryMap(persistentPersons(k)).ConsecutiveFrames = personHistoryMap(persistentPersons(k)).ConsecutiveFrames + 1;
            persistentPersons(k) = [];  % Remove from unmatched list
        end
    end

    % Create new tracks for unmatched detections
    for m = 1:size(bbox, 1)
        if ~ismember(m, persistentPersons)
            personHistoryMap(m) = struct('LastBoundingBox', bbox(m, :), 'ConsecutiveFrames', consecutiveFramesThreshold);
            persistentPersons = [persistentPersons, m];
        end
    end

    % Display the frame with detected people using implay
    step(videoPlayer, frame);
    title('Detected People');

    pause(1 / (vid.FrameRate * playbackSpeed));
end

% Release the video player
release(videoPlayer);