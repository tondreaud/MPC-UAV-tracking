clc
close all
clear all

%load Waypoints and State Constraint points
load('WP_map.mat');
X=dd(:,1);
Y=dd(:,2);
Z=dd(:,3);

%% Middle Start Stuff here
iter = 10000;

% Add path to old data
addpath('C:\Users\shawn\Desktop\Advanced-Control-Design-Final-Project\Data\Partial Run 725 Sunday')
load('last_state.mat')
% load('OpenLoopPred.mat') % OL is saved in new way so this data will be separated
load('U.mat')
load('Z.mat')

% Hardcode Start idx
goal_idx = 566;

% Hardcode iteration
n = 2341;
n = n+1;

% initialize state
z = last_state;

% Initialize remainder of z_list and u_list
z_list(:,n+1:iter) = 0;
u_list(:,n+1:iter) = 0;

%%
% Define timestep
Ts = 0.1;

waypoints = [X,Y,Z]';

% Determine distance between waypoints
normVec = [];
for i = 1:size(waypoints,2)-1
    normVec(i) = norm(waypoints(:,i+1) - waypoints(:,i));
end

% set reference velocity
v_ref = 50;

% Define horizon
N = 35;

dist_trav_des = 0;

% Define cell arrays to store open loop trajectories
openloop_z = cell(1,iter);
openloop_u = cell(1,iter);
openloop_J = cell(1,iter);
openloop_Ninterp = cell(1,iter);

wp_final = 0;
counter = 0;

%%
for M=n:iter
    
current_dis = vecnorm(waypoints-z(1:3), 2,1);
[val,current_idx] = min(current_dis);

% Break if reached final waypoint
if current_idx == size(dd,1)
    break
end

umax = [9000 9000 9000 9000]';
umin = [0 0 0 0]';

% Define goal state constraints 
current = [waypoints(:, current_idx)];
goal = [waypoints(:, goal_idx)];
disp(['Goal Index:', num2str(goal_idx)])

[pointsInterp] = Ninterp(waypoints, current_idx, goal_idx, N+1);
openloop_Ninterp{M} = pointsInterp;
x_interp = pointsInterp(:,1);
y_interp = pointsInterp(:,2);
z_interp = pointsInterp(:,3);

zN = [];
for k=1:N+1
    zN(:,k) = [x_interp(k); y_interp(k); z_interp(k);  v_ref];
end
    
% Define constraints on roll, pitch, and roll, pitch derivatives (not currently defining
% constraint for velocity)
zMax = [rad2deg(15) rad2deg(15) rad2deg(10) rad2deg(10)]';
zMin = [rad2deg(-15) rad2deg(-15) rad2deg(-10) rad2deg(-10)]';

disp(['Currently Solving for iter:', num2str(M)])
[feas, zOpt, uOpt, JOpt] = CFTOC(N, z, zN, zMin, zMax, umin, umax, Ts);
if feas == 0
    disp("ERROR IN YALMIP CFTOC");
    break;
end

openloop_z{M} = zOpt;
openloop_u{M} = uOpt;
openloop_J{M} = JOpt;

u = uOpt(:, 1);
z = zOpt(:, 2);

z_list(:,M) = z;
u_list(:,M) = u;

% propogate goal_idx
dist_trav_des = dist_trav_des + v_ref*Ts;
wp_dist = norm(waypoints(:, goal_idx-1) - waypoints(:, goal_idx));

if dist_trav_des > wp_dist && ~wp_final
    goal_idx = goal_idx + 1;
    dist_trav_des = 0;
end

% Stop propogating waypoints when reaching final (see wp_final flag above)
if goal_idx == size(dd,1)
    wp_final = 1;    
end
end

save Z z_list
save U u_list
save OpenLoopPred openloop_z openloop_u openloop_J
if feas ~= 0
    traj_plot(z_list(:,1:M), dd)
end


function [feas, zOpt, uOpt, JOpt] = CFTOC(N, z0, zN, zmin, zmax, umin, umax, Ts)

% Define state matrix
z = sdpvar(12,N+1);

% Define input decision variables
u = sdpvar(4,N);

%define lane constraints
buff = 0;
tube_radius = 50;
quadcopter_width = 2;

P = eye(3);
Q = eye(3);
R = 10*eye(4);
VEL_weight = eye(3);

%define objective function
objective=0;

objective = (z(1:3,N+1) - zN(1:3,N+1))'*P*(z(1:3,N+1) - zN(1:3,N+1));
for j=1:N
    objective = objective + (z(1:3,j) - zN(1:3,N+1))'*Q*(z(1:3,j) - zN(1:3,N+1)) - z(4:6,j)'*VEL_weight*z(4:6,j);
    objective = objective + u(:,j)'*R*u(:,j);
end

%define state and input constraints
constraints = [];
constraints = [constraints z(:,1)==z0];
for i = 1:N
    constraints = [constraints, (-tube_radius+buff+quadcopter_width/2)<=( z(1,i)-zN(1,i)) <= (tube_radius- buff - quadcopter_width/2)];
    constraints = [constraints, (-tube_radius+buff+quadcopter_width/2)<=( z(2,i)-zN(2,i)) <= (tube_radius- buff - quadcopter_width/2)];
    constraints = [constraints, (-tube_radius+buff+quadcopter_width/2)<=( z(3,i)-zN(3,i)) <= (tube_radius- buff - quadcopter_width/2)];
    
    constraints = [constraints umin<=u(:,i)<=umax];
    constraints = [constraints z(:,i+1) == linearDynamicsQuadcopterDiscrete(z(:,i), u(1,i), u(2,i), u(3,i), u(4,i), Ts)];
end
for k=1:N+1
%      constraints=[constraints zmin(1:2)<=z(7:8,k)<=zmax(1:2) zmin(3:4)<=z(10:11,k)<=zmax(3:4)];
end
constraints=[constraints z(1:3,N+1) == zN(1:3,N)];

% Set options for YALMIP and solver
options = sdpsettings('verbose', 0, 'solver', 'quadprog');
% Solve
sol = optimize(constraints, objective, options);
if sol.problem == 0
    feas = 1;
    zOpt = value(z);
    uOpt = value(u);
    JOpt = value(objective);
else
    feas=0;
    zOpt = [];
    uOpt = [];
    JOpt = value(objective);
end

end

function [dd] = Ninterp(waypoints, current_idx, goal_idx, N)

WP = waypoints(:,current_idx:goal_idx)';

temp = cat(1,0,cumsum(sqrt(sum(diff(WP,[],1).^2,2))));
dd = interp1(temp, WP, unique([temp(:)' linspace(0,temp(end),N)]),'PCHIP');

end


