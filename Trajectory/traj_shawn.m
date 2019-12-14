%% Trajectory
% This scripts generates the interpolated data for the reference trajectory
close all; clc; clear all;

% 32187 is 20mi
r.x = 32187;
r.y = 32187;
r.z = 32187;

% theta = linspace(0,2*pi,360);
% x = r.x*cos(theta);
% y = r.y*sin(theta);
% z = r.z*sin(theta);
% circlewaypoints = [x',y',z'];
% plot3(x,y,z)
% grid on
% axis square

WP =...
    [0 0 0;
    25 0 25;
    40 0 50;
    60 0 50;
    80 0 50;
    80 10 50;
    80 30 50;
    60 40 50;
    40 60 50;
    20 80 50;
     0 120 50; 
    -5 100 50;
    -5 80 50;
   -10 60 50;
   -10 40 50;
   -10 25 50;
     0  0 50];
 
WP = 8*WP; 
temp = cat(1,0,cumsum(sqrt(sum(diff(WP,[],1).^2,2))));
interpWP = interp1(temp, WP, unique([temp(:)' linspace(0,temp(end),200)]),'cubic');

dd = interpWP;

save 'waypoints_lesscurve.mat' dd

% 
% figure, hold on
% plot3(WP(:,1),WP(:,2),WP(:,3),'.b-')
% plot3(interpWP(:,1),interpWP(:,2),interpWP(:,3),'.r-')
% 
% grid on
% title('Quadcopter Trajectoy')
% axis image, view(3), legend({'Original','Interp. Spline'})