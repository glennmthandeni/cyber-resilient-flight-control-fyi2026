%--------------------------------------------------------------------------
% FYI Cyber-Twin Trim Initialization
% Loads workspace data, applies trim values, and runs edited model.
%--------------------------------------------------------------------------

% clear
% clc
% close all
clc

% Do not use clear, clear all, clear classes, or close all here.
% This init script may be called while the App Designer dashboard is open.

%% Model name

mdl = 'FYI_Twin_CyberResilient';

%% Load required aircraft/state workspace data

workspaceFile = 'FYI_Workspace_Data.mat';

if ~isfile(workspaceFile)
    error(['Cannot find ', workspaceFile, ...
           '. Run the original model once and save aircraft, state, thrustX first.'])
end

load(workspaceFile,'aircraft','state','thrustX')

%% Load edited model

load_system(mdl)

%% Push original objects immediately

assignin('base','aircraft',aircraft)
assignin('base','state',state)
assignin('base','thrustX',thrustX)

mw = get_param(mdl,'ModelWorkspace');

assignin(mw,'aircraft',aircraft)
assignin(mw,'state',state)
assignin(mw,'thrustX',thrustX)

%% Simulation settings
required_count = 5;
blend_rate = 0.05;
TF = 60;                  % Simulation time, s

%% Trimmed 6DOF EOM initial states

% Attitude states
phi0   = 0.0092342;        % roll angle, rad
theta0 = 0.29658;          % pitch angle, rad
psi0   = 0.0;              % yaw angle, rad

% Angular rates
p0 = 3.0707e-20;           % roll rate, rad/s
q0 = 5.1124e-22;           % pitch rate, rad/s
r0 = -8.6217e-20;          % yaw rate, rad/s

% Body-axis velocities
U0 = 33.0529;              % forward body velocity, m/s
V0 = 0.093272;             % side body velocity, m/s
W0 = 10.1004;              % vertical body velocity, m/s

% Local NED inertial positions
Xe0 = -2.8165e-12;         % north position, m
Ye0 = 4.3033e-12;          % east position, m
Ze0 = -2202;               % down position, m

altitude0 = -Ze0;          % altitude above reference, m

%% Override the loaded state object with trim values

state.Phi   = phi0;
state.Theta = theta0;
state.Psi   = psi0;

state.P = p0;
state.Q = q0;
state.R = r0;

state.U = U0;
state.V = V0;
state.W = W0;

state.XN = Xe0;
state.XE = Ye0;
state.XD = Ze0;

state.AltitudeMSL = altitude0;
%state.AltitudeAGL = altitude0;

%state.BodyVelocity   = [U0, V0, W0];
%state.GroundVelocity = [U0, V0, W0];

%% Trimmed actuator commands

AileronCmd  = 0.0013469;   % rad
ElevatorCmd = -0.14185;    % rad
RudderCmd   = -0.03733;    % rad

%% Throttle / propulsion command

% The trim report gives aileron, elevator, and rudder trim values.
% Throttle is not listed in the same trim-input table, so start with
% the original model value and tune only if the aircraft still
% slowly gains or loses energy.
ThrottleCmd = 0.5;

%% Attack settings

% %Attack mode
% attack_mode = 1;
% % Keep attack disabled while checking trimmed flight stability.
% attack_enable = 1;
%% Attack settings

% Do not overwrite attack settings if the dashboard/app already set them.
if ~exist('attack_mode','var')
    attack_mode = 3;
end

if ~exist('attack_enable','var')
    attack_enable = 1;
end
%% Reference geodetic location for FlightGear conversion

lat0_deg = 48.3540;
lon0_deg = 11.7884;

lat0 = deg2rad(lat0_deg);
lon0 = deg2rad(lon0_deg);

%% Native initial state vector

% Aerospace Blockset 6DOF state order:
% [phi; theta; psi; p; q; r; U; V; W; Xe; Ye; Ze]

x0 = [
    phi0;
    theta0;
    psi0;
    p0;
    q0;
    r0;
    U0;
    V0;
    W0;
    Xe0;
    Ye0;
    Ze0
];

%% Unified state vector for your cyber/digital-twin architecture

% Your current adapted order:
% [u; v; w; phi; theta; psi; p; q; r; lon; lat; h]

x0_unified = [
    U0;
    V0;
    W0;
    phi0;
    theta0;
    psi0;
    p0;
    q0;
    r0;
    lon0;
    lat0;
    altitude0
];

%% Actuator command vector

ActuatorCmds = [
    AileronCmd;
    ElevatorCmd;
    RudderCmd
];

%% If any old 5-input twin block still exists, keep this compatibility vector

% [aileron; elevator; rudder; throttle1; throttle2]
u_twin = [
    AileronCmd;
    ElevatorCmd;
    RudderCmd;
    ThrottleCmd;
    ThrottleCmd
];

%% Push variables to base workspace

assignin('base','mdl',mdl)
assignin('base','workspaceFile',workspaceFile)
assignin('base','TF',TF)

assignin('base','aircraft',aircraft)
assignin('base','state',state)
assignin('base','thrustX',thrustX)

assignin('base','phi0',phi0)
assignin('base','theta0',theta0)
assignin('base','psi0',psi0)

assignin('base','p0',p0)
assignin('base','q0',q0)
assignin('base','r0',r0)

assignin('base','U0',U0)
assignin('base','V0',V0)
assignin('base','W0',W0)

assignin('base','Xe0',Xe0)
assignin('base','Ye0',Ye0)
assignin('base','Ze0',Ze0)
assignin('base','altitude0',altitude0)

assignin('base','AileronCmd',AileronCmd)
assignin('base','ElevatorCmd',ElevatorCmd)
assignin('base','RudderCmd',RudderCmd)
assignin('base','ThrottleCmd',ThrottleCmd)
assignin('base','ActuatorCmds',ActuatorCmds)

assignin('base','attack_mode',attack_mode)
assignin('base','attack_enable',attack_enable)
assignin('base','blend_rate',blend_rate)
assignin('base','required_count',required_count)

assignin('base','lat0_deg',lat0_deg)
assignin('base','lon0_deg',lon0_deg)
assignin('base','lat0',lat0)
assignin('base','lon0',lon0)

assignin('base','x0',x0)
assignin('base','x0_unified',x0_unified)
assignin('base','u_twin',u_twin)

%% Push important variables to model workspace too

assignin(mw,'TF',TF)

assignin(mw,'aircraft',aircraft)
assignin(mw,'state',state)
assignin(mw,'thrustX',thrustX)

assignin(mw,'phi0',phi0)
assignin(mw,'theta0',theta0)
assignin(mw,'psi0',psi0)

assignin(mw,'p0',p0)
assignin(mw,'q0',q0)
assignin(mw,'r0',r0)

assignin(mw,'U0',U0)
assignin(mw,'V0',V0)
assignin(mw,'W0',W0)

assignin(mw,'Xe0',Xe0)
assignin(mw,'Ye0',Ye0)
assignin(mw,'Ze0',Ze0)
assignin(mw,'altitude0',altitude0)

assignin(mw,'AileronCmd',AileronCmd)
assignin(mw,'ElevatorCmd',ElevatorCmd)
assignin(mw,'RudderCmd',RudderCmd)
assignin(mw,'ThrottleCmd',ThrottleCmd)
assignin(mw,'ActuatorCmds',ActuatorCmds)

assignin(mw,'attack_mode',attack_mode)
assignin(mw,'attack_enable',attack_enable)
assignin(mw,'blend_rate',blend_rate)
assignin(mw,'required_count',required_count)

assignin(mw,'lat0_deg',lat0_deg)
assignin(mw,'lon0_deg',lon0_deg)
assignin(mw,'lat0',lat0)
assignin(mw,'lon0',lon0)

assignin(mw,'x0',x0)
assignin(mw,'x0_unified',x0_unified)
assignin(mw,'u_twin',u_twin)

% %% Display loaded values
% 
% disp('--------------------------------------------')
% disp('FYI TRIM WORKSPACE LOADED')
% disp('--------------------------------------------')
% fprintf('Loaded workspace file : %s\n', workspaceFile)
% fprintf('aircraft.ReferenceArea: %.4f\n', aircraft.ReferenceArea)
% fprintf('state.Mass           : %.4f kg\n', state.Mass)
% fprintf('state.GroundHeight   : %.4f m\n', state.GroundHeight)
% fprintf('U0                   : %.4f m/s\n', U0)
% fprintf('V0                   : %.4f m/s\n', V0)
% fprintf('W0                   : %.4f m/s\n', W0)
% fprintf('phi0                 : %.6f rad = %.3f deg\n', phi0, rad2deg(phi0))
% fprintf('theta0               : %.6f rad = %.3f deg\n', theta0, rad2deg(theta0))
% fprintf('psi0                 : %.6f rad = %.3f deg\n', psi0, rad2deg(psi0))
% fprintf('p0                   : %.4e rad/s\n', p0)
% fprintf('q0                   : %.4e rad/s\n', q0)
% fprintf('r0                   : %.4e rad/s\n', r0)
% fprintf('Xe0                  : %.4e m\n', Xe0)
% fprintf('Ye0                  : %.4e m\n', Ye0)
% fprintf('Ze0                  : %.2f m\n', Ze0)
% fprintf('Altitude             : %.2f m\n', altitude0)
% fprintf('AileronCmd           : %.6f rad = %.3f deg\n', AileronCmd, rad2deg(AileronCmd))
% fprintf('ElevatorCmd          : %.6f rad = %.3f deg\n', ElevatorCmd, rad2deg(ElevatorCmd))
% fprintf('RudderCmd            : %.6f rad = %.3f deg\n', RudderCmd, rad2deg(RudderCmd))
% fprintf('ThrottleCmd          : %.3f\n', ThrottleCmd)
% fprintf('Attack enabled       : %d\n', attack_enable)
% disp('--------------------------------------------')

%% Set stop time and update model

set_param(mdl,'StopTime','TF')
set_param(mdl,'SimulationCommand','update')

% Run model

%sim(mdl)