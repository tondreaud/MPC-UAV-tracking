%% Trajectory Plotting
function [] = traj_plot(z_list, WP)
% This scripts generates the interpolated data for the reference trajectory
close all; 

% WP =...
%     [0 0 0;
%     25 0 25;
%     40 0 50;
%     60 0 50;
%     80 0 25;
%     100 0 0;
%     80 30 25;
%     60 40 50;
%     40 60 50;
%     20 80 50;
%      0 120 0; 
%     -5 100 25];
% %     -5 80 30;
% %    -10 60 50;
% %    -10 40 50;
% %    -10 25 25;
% %      0  0 0];
%  WP = 10*WP;

temp = cat(1,0,cumsum(sqrt(sum(diff(WP,[],1).^2,2))));
dd = interp1(temp, WP, unique([temp(:)' linspace(0,temp(end),800)]),'cubic');

figure, hold on
% plot3(WP(:,1),WP(:,2),WP(:,3),'.b-')
plot3(dd(:,1),dd(:,2),dd(:,3),'.r-')
plot3(z_list(1,:),z_list(2,:),z_list(3,:), 'b', 'linewidth', 2)

grid on
title('Waypoints vs Quadcopter Trajectoy')
axis image, view(3), legend({'Interp. Spline of Waypoints','Quadcopter Trajectory'})