function X=plot_OL_visualisation()
%load('U.mat')
load('Z.mat')
load('OpenLoopPred_part1.mat')
openfig('3D_trajectory.fig')
xlim([3538 4110])
ylim([2134 2691])
zlim([46.78 714.3])

legend('Reference Trajectory') 
for i=400:length(openloop_z)  
    zOL_step = [];
    zOL_step = openloop_z{i};
    hold on
    g=plot3(z_list(1,i), z_list(2,i), z_list(3,i),'b.-', 'MarkerSize', 10)
    legend('Closed Loop')
    h=plot3(zOL_step(1,:), zOL_step(2,:), zOL_step(3,:),'m.-', 'linewidth', 1)
    legend('Open Loop')
    f=plot3(zOL_step(1,end), zOL_step(2,end), zOL_step(3,end),'g*', 'MarkerSize', 10)
    legend('Terminal Set')
    pause(0.2)
    delete(h)
    delete(f)
end
    X=1;
end