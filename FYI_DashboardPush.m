function y = FYI_DashboardPush(packet)
%--------------------------------------------------------------------------
% FYI_DashboardPush
%
% Called from Simulink through an Interpreted MATLAB Function block.
% Pushes live simulation data to the App Designer dashboard.
%
% Input:
% packet = [62x1] vector
%
% Output:
% y = dummy scalar output for Simulink
%--------------------------------------------------------------------------

y = 0;

persistent lastUpdateTime

if isempty(lastUpdateTime)
    lastUpdateTime = tic;
end

% Limit UI update rate to about 10 Hz.
% This prevents the app from slowing down the simulation too much.
if toc(lastUpdateTime) < 0.10
    return;
end

lastUpdateTime = tic;

try
    % Save last packet for debugging
    assignin('base','FYI_DASHBOARD_LAST_PACKET',packet)

    % Get running dashboard app from base workspace
    app = evalin('base','FYI_DASHBOARD_APP');

    if isempty(app)
        return;
    end

    if ~isvalid(app.UIFigure)
        return;
    end

    % Push live packet to app
    app.pushLivePacket(packet);

catch ME
    assignin('base','FYI_DASHBOARD_LAST_ERROR',ME.message);
end

end