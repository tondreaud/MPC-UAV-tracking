clc
close all
clear all

%load Waypoints and State Constraint points
% load('WayP.mat')
load('wpx8.mat');
% load('WayP.mat');
X=dd(:,1);
Y=dd(:,2);
Z=dd(:,3);

% load('circleWP.mat');
% X=circlewaypoints(:,1);
% Y=circlewaypoints(:,2);
% Z=circlewaypoints(:,3);

% load('Constraints.mat')
% Define timestep
Ts = 0.1;

waypoints = [X,Y,Z]';

% Determine distance between waypoints
normVec = [];
for i = 1:size(waypoints,2)-1
    normVec(i) = norm(waypoints(:,i+1) - waypoints(:,i));
end

%define initial heading angle
% heading = atan((Y(2)-Y(1)) / (X(2) - X(1)));
%define end target
final = waypoints(:,end);

%set initial localization
% z0 = [X(1); Y(1); Z(1); zeros(9,1)]; % initial heigth of 0 for now
% z0 = zeros(12,1);
z0 = [264.334579554578;6.37302432870657e-17;193.462025344637;1.36001436380456e-09;8.07781392920884e-17;2.08965197162777e-14;1.22923215490388e-17;2.62946516276818e-11;-4.51266628231915e-16;-1.17738245147906e-17;-2.57248566250427e-10;-4.22838847269347e-18];
z  = z0;
z_list = z;
u_list = [];
openloop_z = {};
openloop_u = {};
openloop_pointsInterp = {};

% set reference velocity
v_ref = 2;
vCur = 0;

% Define horizon
N = 20;
i = 0;

% Initialize idx
current_idx = 1;
goal_idx = 1;

%while the model has not reached within a certain tolerance of the end
%point
%while norm(z(1:3) - final) > 2
for M=1:2000000
    
    %     dist=z0(3)*Ts;
    %     x_pos=z0(1)+cos(z0(4))*dist;
    %     y_pos=z0(2)+sin(z0(4))*dist;
    %     for i =current_idx+1:length(waypoints)
    %         x=waypoints(1,i);
    %         y=waypoints(2,i);
    %         if x>x_pos && y>y_pos
    %             goal_idx=current_idx+i;
    %             break
    %         end
    %     end
    % Define input constraints (force of each propeller)
    
    current_dis = vecnorm(waypoints-z(1:3), 2,1);
    last_current_idx = current_idx;
%     current_idx = find(current_dis == min(current_dis));
    [val,current_idx] = min(current_dis);
    
    if current_idx < last_current_idx
        current_idx = last_current_idx + 1;
    end
    %     goal_idx = current_idx + 5;
    
    umax = [9000 9000 9000 9000]';
    umin = [0 0 0 0]';
    
    vCur = z0(4:6);
    % Grab currenct velocity
    if norm(vCur) <= 1.0
        vCur = v_ref;
    end
    
    % Find distance traveled in N time steps
    distInN = norm(vCur)*N*Ts;
    
    k = 0;
    distance2goal = 0;
    while (distance2goal < distInN)
        distance2goal = distance2goal + normVec(current_idx + k);
        k = k + 1;
    end
    
    last_goal_idx = goal_idx;
    goal_idx = current_idx + k;
    if goal_idx < last_goal_idx
        goal_idx = last_goal_idx;
    end
    
    % Define goal state constraints (X,Y,V,Heading)
    current = [waypoints(:, current_idx)];
    goal = [waypoints(:, goal_idx)];
    disp(['Goal Index:', num2str(goal_idx)])
    
    [pointsInterp] = Ninterp(waypoints, current_idx, goal_idx, vCur, Ts, N);
    openloop_pointsInterp(M) = {pointsInterp};
    
    x_interp=[];
    y_interp=[];
    z_interp=[];
    
    x_interp = pointsInterp(:,1);
    y_interp = pointsInterp(:,2);
    z_interp = pointsInterp(:,3);
    
    %     %calculate distance between points
    %     delta=v_ref*Ts;
    
    %     %calculate next n-points to interpolate
    %     x_interp=[];
    %     y_interp=[];
    %     z_interp=[];
    %     angle_xy=atan((goal(2)-z0(2))/(goal(1)-z0(1)));
    %     angle_xz=atan((goal(3)-z0(3))/(goal(1)-z0(1)));
    %     for j=1:N
    %         x_interp=[x_interp z0(1)+cos(angle_xy)*j*delta];
    %         y_interp=[y_interp z0(2)+sin(angle_xy)*j*delta];
    %         z_interp=[z_interp z0(3)+sin(angle_xz)*j*delta];
    %     end
    
    zN = [];
    for k=1:N
        zN(:,k) = [x_interp(k); y_interp(k); z_interp(k);  vCur];
    end
    
    % Define constraints on roll, pitch, and roll, pitch derivatives (not currently defining
    % constraint for velocity)
    zMax = [15 15 10 10]';
    zMin = [-15 -15 -10 -10]';
    
    disp(['Currently Solving for iter:', num2str(i)])
    [feas, zOpt, uOpt, JOpt] = CFTOC(N, z0, zN, zMin, zMax, umin, umax, Ts);
    if feas == 0
        disp("ERROR IN YALMIP CFTOC");
        break;
    end
    
    u = uOpt(:, 1);
    z = zOpt(:, 2);
    z_list = [z_list z];
    u_list = [u_list u];
    openloop_z(M) = {zOpt};
    openloop_u(M) = {uOpt};
    z0 = z;
    
    i = i + 1;
end

if feas ~= 0
    traj_plot(z_list, dd);
end

function [feas, zOpt, uOpt, JOpt] = CFTOC(N, z0, zN, zmin, zmax, umin, umax, Ts)

% Define state matrix
z = sdpvar(12,N+1);

% Define input decision variables
u = sdpvar(4,N);

%define lane constraints
buff = 0;
tube_radius = 10;
quadcopter_width = 2;

P = 5*eye(3);
Q = eye(3);
R = 10*eye(4);

%define objective function
objective=0;

objective = (z(1:3,N+1) - zN(1:3,N))'*P*(z(1:3,N+1) - zN(1:3,N));
for j=1:N
    objective = objective + (z(1:3,j) - zN(1:3,N))'*Q*(z(1:3,j) - zN(1:3,N)); % removed velocity goal
    objective = objective + u(:,j)'*R*u(:,j);
end

%define state and input constraints
constraints = [];
constraints = [constraints z(:,1)==z0];
for i = 1:N
    %     	    constraints = [constraints zmin<=z(:,i)<=zmax];
    %find the absolute value of the current position from the reference
    %     dist_ref = abs((z(1,i)-zN(1,i))^2+(z(2,i)-zN(2,i))^2+(z(3,i)-zN(3,i))^2);
    %     constraints = [constraints (dist_ref+buff+quadcopter_width/2) <= (lane_width/2) ];
    constraints = [constraints, (-tube_radius+buff+quadcopter_width/2)<=( z(1,i)-zN(1,i)) <= (tube_radius- buff - quadcopter_width/2)];
    constraints = [constraints, (-tube_radius+buff+quadcopter_width/2)<=( z(2,i)-zN(2,i)) <= (tube_radius- buff - quadcopter_width/2)];
    constraints = [constraints, (-tube_radius+buff+quadcopter_width/2)<=( z(3,i)-zN(3,i)) <= (tube_radius- buff - quadcopter_width/2)];
    
    constraints = [constraints umin<=u(:,i)<=umax];
    constraints = [constraints z(:,i+1) == linearDynamicsQuadcopterDiscrete(z(:,i), u(1,i), u(2,i), u(3,i), u(4,i), Ts)];
    %     if i <= N-1
    %         % 	        constraints = [constraints -pi/10<=u(2,i+1)-u(2,i)<=pi/10];
    %     end
end
for k=1:N+1
    constraints=[constraints zmin(1:2)<=z(7:8,k)<=zmax(1:2) zmin(3:4)<=z(10:11,k)<=zmax(3:4)];
end
constraints=[constraints z(1:3,N+1) == zN(1:3,N)];

% Set options for YALMIP and solver
optimoptions(@quadprog,'StepTolerance',1e-6,'OptimalityTolerance',1e-4,'ConstraintTolerance',1e-4);
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

function [dd] = Ninterp(waypoints, current_idx, goal_idx, vCur, Ts, N)

WP = waypoints(:,current_idx:goal_idx)';

temp = cat(1,0,cumsum(sqrt(sum(diff(WP,[],1).^2,2))));
dd = interp1(temp, WP, unique([temp(:)' linspace(0,temp(end),N)]),'PCHIP');

end


