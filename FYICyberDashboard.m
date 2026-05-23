classdef FYICyberDashboard < matlab.apps.AppBase
    % FYICyberDashboard
    %
    % Cockpit-style cyber-physical integrity dashboard for the
    % FYI_Twin_CyberResilient Simulink model.
    %
    % Required logged Simulink signals:
    %   residual_norm
    %   post_RAM_residual_norm
    %   residual_selected
    %   post_RAM_residual_selected
    %   cyber_flag
    %   RAM_active
    %   ram_blend
    %   x_meas_attacked
    %   x_pred_unified
    %   x_safe
    %   x_true_unified

    properties (Access = public)
        UIFigure matlab.ui.Figure

        % Main panels
        HeaderPanel matlab.ui.container.Panel
        StatusPanel matlab.ui.container.Panel
        ControlPanel matlab.ui.container.Panel
        PlotPanel matlab.ui.container.Panel

        % Labels
        TitleLabel matlab.ui.control.Label
        SubtitleLabel matlab.ui.control.Label
        CyberStatusLabel matlab.ui.control.Label
        RAMStatusLabel matlab.ui.control.Label
        TrustedStateLabel matlab.ui.control.Label
        ScenarioLabel matlab.ui.control.Label
        ModelLabel matlab.ui.control.Label

        % Lamps
        NormalLamp matlab.ui.control.Lamp
        NormalLampLabel matlab.ui.control.Label
        AttackLamp matlab.ui.control.Lamp
        AttackLampLabel matlab.ui.control.Label
        RAMStandbyLamp matlab.ui.control.Lamp
        RAMStandbyLampLabel matlab.ui.control.Label
        RAMActiveLamp matlab.ui.control.Lamp
        RAMActiveLampLabel matlab.ui.control.Label

        % Gauge and numeric displays
        RAMBlendGauge matlab.ui.control.LinearGauge
        RAMBlendGaugeLabel matlab.ui.control.Label
        CyberFlagDisplay matlab.ui.control.NumericEditField
        CyberFlagDisplayLabel matlab.ui.control.Label
        RAMActiveDisplay matlab.ui.control.NumericEditField
        RAMActiveDisplayLabel matlab.ui.control.Label

        % Controls
        RunNominalButton matlab.ui.control.Button
        RunAltitudeSpoofButton matlab.ui.control.Button
        RunAirDataSpoofButton matlab.ui.control.Button
        RunCoordinatedAttackButton matlab.ui.control.Button
        StopButton matlab.ui.control.Button
        RefreshButton matlab.ui.control.Button
        StopTimeField matlab.ui.control.NumericEditField
        StopTimeFieldLabel matlab.ui.control.Label

        % Axes
        ResidualAxes matlab.ui.control.UIAxes
        AltitudeAxes matlab.ui.control.UIAxes
        PitchAxes matlab.ui.control.UIAxes
        SelectedResidualAxes matlab.ui.control.UIAxes
    end

    properties (Access = private)
        ModelName char = 'FYI_Twin_CyberResilient'
        InitScript char = 'Init_Cyber'
        LastSimOut

        % Live Simulink-push buffers
        LiveTime double = []
        LiveRawResidual double = []
        LivePostResidual double = []
        LiveCyberFlag double = []
        LiveRAMActive double = []
        LiveRAMBlend double = []

        LiveAltitudeMeas double = []
        LiveAltitudePred double = []
        LiveAltitudeSafe double = []
        LiveAltitudeTrue double = []

        LivePitchMeas double = []
        LivePitchPred double = []
        LivePitchSafe double = []
        LivePitchTrue double = []

        LiveSelectedResidual double = []

        % Cockpit indication gate: lamps latch only after trusted-state
        % transfer reaches 100% (implemented as >= 99.5% to avoid roundoff)
        DashboardStatusLatched logical = false
        StatusGateThreshold double = 0.995
    end

    methods (Access = private)

        function startupFcn(app)
            app.setInitialLampState();
            app.ModelLabel.Text = ['Model: ', app.ModelName];

            try
                if ~bdIsLoaded(app.ModelName)
                    load_system(app.ModelName);
                end
            catch ME
                uialert(app.UIFigure, ...
                    ['Could not load Simulink model: ', ME.message], ...
                    'Model Load Warning');
            end
        end

        function setInitialLampState(app)
            app.DashboardStatusLatched = false;

            app.NormalLamp.Color = [0.0 0.8 0.0];
            app.AttackLamp.Color = [0.25 0.25 0.25];

            app.RAMStandbyLamp.Color = [0.0 0.8 0.0];
            app.RAMActiveLamp.Color = [0.25 0.25 0.25];

            app.CyberFlagDisplay.Value = 0;
            app.RAMActiveDisplay.Value = 0;
            app.RAMBlendGauge.Value = 0;
            app.TrustedStateLabel.Text = 'TRUSTED STATE SOURCE: MEASURED STATE';
            app.TrustedStateLabel.FontColor = [0.4 1.0 0.4];
        end

        function setAttackState(app, cyberFlag, ramActive, ramBlend)
            cyberFlag = double(cyberFlag);
            ramActive = double(ramActive);
            ramBlend = max(0,min(1,double(ramBlend)));

            % Gate the cockpit-style indication. The raw internal cyber_flag
            % and RAM_active can flicker during small transient spikes. The
            % dashboard lamps should only commit when the trusted-state transfer
            % has fully completed.
            transferComplete = (ramBlend >= app.StatusGateThreshold);

            if transferComplete && ((cyberFlag >= 0.5) || (ramActive >= 0.5))
                app.DashboardStatusLatched = true;
            end

            if app.DashboardStatusLatched
                app.NormalLamp.Color = [0.25 0.25 0.25];
                app.AttackLamp.Color = [1.0 0.0 0.0];

                app.RAMStandbyLamp.Color = [0.25 0.25 0.25];
                app.RAMActiveLamp.Color = [1.0 0.75 0.0];

                app.CyberFlagDisplay.Value = 1;
                app.RAMActiveDisplay.Value = 1;
            else
                app.NormalLamp.Color = [0.0 0.8 0.0];
                app.AttackLamp.Color = [0.25 0.25 0.25];

                app.RAMStandbyLamp.Color = [0.0 0.8 0.0];
                app.RAMActiveLamp.Color = [0.25 0.25 0.25];

                app.CyberFlagDisplay.Value = 0;
                app.RAMActiveDisplay.Value = 0;
            end

            app.RAMBlendGauge.Value = 100 * ramBlend;

            if ramBlend < 0.05
                app.TrustedStateLabel.Text = 'TRUSTED STATE SOURCE: MEASURED STATE';
                app.TrustedStateLabel.FontColor = [0.4 1.0 0.4];
            elseif ramBlend < app.StatusGateThreshold
                app.TrustedStateLabel.Text = 'TRUSTED STATE SOURCE: TRANSITIONING TO DIGITAL TWIN';
                app.TrustedStateLabel.FontColor = [1.0 0.85 0.2];
            else
                app.TrustedStateLabel.Text = 'TRUSTED STATE SOURCE: RAM SAFE STATE';
                app.TrustedStateLabel.FontColor = [1.0 0.45 0.1];
            end
        end

        function runScenario(app, attackEnable, attackMode, scenarioName)
            app.ScenarioLabel.Text = ['Scenario: ', scenarioName];

            app.resetLiveData();
            app.setInitialLampState();
            app.clearPlots();

            try
                if ~bdIsLoaded(app.ModelName)
                    load_system(app.ModelName);
                end

                % Stop any currently running simulation.
                try
                    simStatus = get_param(app.ModelName,'SimulationStatus');
                    if ~strcmp(simStatus,'stopped')
                        set_param(app.ModelName,'SimulationCommand','stop');
                        pause(0.5);
                    end
                catch
                end

                % Run initialization script if it exists.
                % The init script must NOT call sim().
                if exist([app.InitScript, '.m'], 'file') == 2 || exist([app.InitScript, '.mlx'], 'file') == 2
                    evalin('base', app.InitScript);
                end

                % Re-apply scenario after init so the init script cannot override it.
                assignin('base', 'attack_enable', attackEnable);
                assignin('base', 'attack_mode', attackMode);

                if evalin('base', 'exist("blend_rate","var")') == 0
                    assignin('base', 'blend_rate', 0.05);
                end

                if evalin('base', 'exist("required_count","var")') == 0
                    assignin('base', 'required_count', 5);
                end

                stopTime = app.StopTimeField.Value;

                set_param(app.ModelName, 'StopTime', num2str(stopTime));
                set_param(app.ModelName, 'ReturnWorkspaceOutputs', 'on');
                set_param(app.ModelName, 'SignalLogging', 'on');
                set_param(app.ModelName, 'SignalLoggingName', 'logsout');
                set_param(app.ModelName, 'SimulationMode', 'normal');

                % Slow simulation to wall clock if available. This makes the live
                % dashboard look like a real-time monitor.
                try
                    set_param(app.ModelName, 'EnablePacing', 'on');
                    set_param(app.ModelName, 'PacingRate', '1');
                catch
                end

                % Register this app so FYI_DashboardPush.m can push live packets.
                assignin('base', 'FYI_DASHBOARD_APP', app);

                % Clear old push diagnostics.
                evalin('base','if exist(''FYI_DASHBOARD_LAST_ERROR'',''var''), clear FYI_DASHBOARD_LAST_ERROR; end');
                evalin('base','if exist(''FYI_DASHBOARD_LAST_PACKET'',''var''), clear FYI_DASHBOARD_LAST_PACKET; end');

                % Start simulation. The Interpreted MATLAB Function block in
                % Simulink must call FYI_DashboardPush(packet).
                set_param(app.ModelName, 'SimulationCommand', 'start');

            catch ME
                uialert(app.UIFigure, ME.message, 'Simulation Error');
            end
        end


        function resetLiveData(app)
            app.LiveTime = [];
            app.LiveRawResidual = [];
            app.LivePostResidual = [];
            app.LiveCyberFlag = [];
            app.LiveRAMActive = [];
            app.LiveRAMBlend = [];

            app.LiveAltitudeMeas = [];
            app.LiveAltitudePred = [];
            app.LiveAltitudeSafe = [];
            app.LiveAltitudeTrue = [];

            app.LivePitchMeas = [];
            app.LivePitchPred = [];
            app.LivePitchSafe = [];
            app.LivePitchTrue = [];

            app.LiveSelectedResidual = [];
        end

        function clearPlots(app)
            cla(app.ResidualAxes);
            cla(app.AltitudeAxes);
            cla(app.PitchAxes);
            cla(app.SelectedResidualAxes);

            title(app.ResidualAxes, 'Consistency Residual: Raw vs Post-RAM');
            xlabel(app.ResidualAxes, 'Time (s)');
            ylabel(app.ResidualAxes, 'Residual Norm');
            grid(app.ResidualAxes, 'on');

            title(app.AltitudeAxes, 'Altitude Channel');
            xlabel(app.AltitudeAxes, 'Time (s)');
            ylabel(app.AltitudeAxes, 'Altitude (m)');
            grid(app.AltitudeAxes, 'on');

            title(app.PitchAxes, 'Pitch Channel');
            xlabel(app.PitchAxes, 'Time (s)');
            ylabel(app.PitchAxes, '\theta (deg)');
            grid(app.PitchAxes, 'on');

            title(app.SelectedResidualAxes, 'Selected Physics Residuals');
            xlabel(app.SelectedResidualAxes, 'Time (s)');
            ylabel(app.SelectedResidualAxes, 'Residual');
            grid(app.SelectedResidualAxes, 'on');
        end

        function fitAxisToData(app, ax)
            %#ok<INUSD>
            lines = findobj(ax, 'Type', 'Line');

            if isempty(lines)
                xlim(ax, [0 1]);
                ylim(ax, [0 1]);
                return;
            end

            allX = [];
            allY = [];

            for k = 1:numel(lines)
                allX = [allX, lines(k).XData(:).']; %#ok<AGROW>
                allY = [allY, lines(k).YData(:).']; %#ok<AGROW>
            end

            allX = allX(isfinite(allX));
            allY = allY(isfinite(allY));

            if ~isempty(allX)
                xmin = min(allX);
                xmax = max(allX);
                if xmin == xmax
                    xmax = xmin + 1;
                end
                xlim(ax, [xmin xmax]);
            end

            if ~isempty(allY)
                ymin = min(allY);
                ymax = max(allY);

                if ymin == ymax
                    margin = max(abs(ymax)*0.1, 1);
                else
                    margin = 0.1 * (ymax - ymin);
                end

                ylim(ax, [ymin - margin, ymax + margin]);
            end
        end

        function updateDashboard(app, simOut)
            % Extract logged signals
            [tRaw, rawResidualNorm] = app.getLogSignal(simOut, 'residual_norm');
            [tPost, postResidualNorm] = app.getLogSignal(simOut, 'post_RAM_residual_norm');

            [tCyber, cyberFlag] = app.getLogSignal(simOut, 'cyber_flag');
            [tRAM, ramActive] = app.getLogSignal(simOut, 'RAM_active');
            [tBlend, ramBlend] = app.getLogSignal(simOut, 'ram_blend');

            [tMeas, xMeas] = app.getLogSignal(simOut, 'x_meas_attacked');
            [tPred, xPred] = app.getLogSignal(simOut, 'x_pred_unified');
            [tSafe, xSafe] = app.getLogSignal(simOut, 'x_safe');
            [tTrue, xTrue] = app.getLogSignal(simOut, 'x_true_unified');

            [tSel, residualSelected] = app.getLogSignal(simOut, 'residual_selected');

            % Update status values using final values
            cyberFinal = app.lastValue(cyberFlag);
            ramFinal = app.lastValue(ramActive);
            blendFinal = app.lastValue(ramBlend);
            app.setAttackState(cyberFinal, ramFinal, blendFinal);

            % Plot 1: residual norm raw vs post-RAM
            cla(app.ResidualAxes);
            hold(app.ResidualAxes, 'on');
            if ~isempty(tRaw)
                plot(app.ResidualAxes, tRaw, rawResidualNorm, 'LineWidth', 1.8);
            end
            if ~isempty(tPost)
                plot(app.ResidualAxes, tPost, postResidualNorm, '--', 'LineWidth', 1.8);
            end
            hold(app.ResidualAxes, 'off');
            grid(app.ResidualAxes, 'on');
            title(app.ResidualAxes, 'Consistency Residual: Raw vs Post-RAM');
            xlabel(app.ResidualAxes, 'Time (s)');
            ylabel(app.ResidualAxes, 'Residual Norm');
            legend(app.ResidualAxes, {'Raw consistency residual', 'Post-RAM residual'}, ...
                'TextColor', 'white', 'Location', 'northeast');

            % Plot 2: altitude channel
            cla(app.AltitudeAxes);
            hold(app.AltitudeAxes, 'on');

            if ~isempty(xTrue)
                plot(app.AltitudeAxes, tTrue, app.stateChannel(xTrue, 12), 'LineWidth', 1.2);
            end

            if ~isempty(xMeas)
                plot(app.AltitudeAxes, tMeas, app.stateChannel(xMeas, 12), 'LineWidth', 1.2);
            end

            if ~isempty(xPred)
                plot(app.AltitudeAxes, tPred, app.stateChannel(xPred, 12), 'LineWidth', 1.2);
            end

            if ~isempty(xSafe)
                plot(app.AltitudeAxes, tSafe, app.stateChannel(xSafe, 12), '--', 'LineWidth', 1.8);
            end

            hold(app.AltitudeAxes, 'off');
            grid(app.AltitudeAxes, 'on');
            title(app.AltitudeAxes, 'Altitude Channel: True / Attacked / Twin / RAM-Safe');
            xlabel(app.AltitudeAxes, 'Time (s)');
            ylabel(app.AltitudeAxes, 'Altitude (m)');
            legend(app.AltitudeAxes, {'True', 'Measured/Attacked', 'Twin Predicted', 'RAM Safe'}, ...
                'TextColor', 'white', 'Location', 'best');

            % Plot 3: pitch channel
            cla(app.PitchAxes);
            hold(app.PitchAxes, 'on');

            if ~isempty(xTrue)
                plot(app.PitchAxes, tTrue, rad2deg(app.stateChannel(xTrue, 5)), 'LineWidth', 1.2);
            end

            if ~isempty(xMeas)
                plot(app.PitchAxes, tMeas, rad2deg(app.stateChannel(xMeas, 5)), 'LineWidth', 1.2);
            end

            if ~isempty(xPred)
                plot(app.PitchAxes, tPred, rad2deg(app.stateChannel(xPred, 5)), 'LineWidth', 1.2);
            end

            if ~isempty(xSafe)
                plot(app.PitchAxes, tSafe, rad2deg(app.stateChannel(xSafe, 5)), '--', 'LineWidth', 1.8);
            end

            hold(app.PitchAxes, 'off');
            grid(app.PitchAxes, 'on');
            title(app.PitchAxes, 'Pitch Channel: True / Attacked / Twin / RAM-Safe');
            xlabel(app.PitchAxes, 'Time (s)');
            ylabel(app.PitchAxes, '\theta (deg)');
            legend(app.PitchAxes, {'True', 'Measured/Attacked', 'Twin Predicted', 'RAM Safe'}, ...
                'TextColor', 'white', 'Location', 'best');

            % Plot 4: selected residuals
            cla(app.SelectedResidualAxes);
            hold(app.SelectedResidualAxes, 'on');

            if ~isempty(residualSelected)
                labels = { ...
                    'u residual (m/s)', ...
                    'w residual (m/s)', ...
                    '\theta residual (rad)', ...
                    'q residual (rad/s)', ...
                    'h residual (m)', ...
                    '\phi residual (rad)', ...
                    'p residual (rad/s)', ...
                    'r residual (rad/s)'};

                for k = 1:8
                    y = app.stateChannel(residualSelected, k);
                    plot(app.SelectedResidualAxes, tSel, y, 'LineWidth', 1.1);
                end

                legend(app.SelectedResidualAxes, labels, ...
                    'TextColor', 'white', 'Location', 'northeastoutside');
            end

            hold(app.SelectedResidualAxes, 'off');
            grid(app.SelectedResidualAxes, 'on');
            title(app.SelectedResidualAxes, 'Selected Physics Consistency Residuals');
            xlabel(app.SelectedResidualAxes, 'Time (s)');
            ylabel(app.SelectedResidualAxes, 'Residual');
        end

        function [t, data] = getLogSignal(app, simOut, signalName)
            %#ok<INUSD>
            t = [];
            data = [];

            try
                logsout = simOut.logsout;
            catch
                return;
            end

            if isempty(logsout)
                return;
            end

            try
                element = logsout.get(signalName);
            catch
                element = [];
            end

            if isempty(element)
                return;
            end

            try
                values = element.Values;
                t = values.Time;
                data = values.Data;
            catch
                t = [];
                data = [];
            end
        end

        function y = stateChannel(app, data, idx)
            %#ok<INUSD>
            % Handles common Simulink logged data shapes:
            % [N x 12], [12 x N], [12 x 1 x N], or [1 x 12 x N]

            y = [];

            if isempty(data)
                return;
            end

            s = size(data);

            if isvector(data)
                if numel(data) >= idx
                    y = data(idx);
                end
                return;
            end

            if numel(s) == 2
                if s(2) >= idx
                    y = data(:, idx);
                elseif s(1) >= idx
                    y = data(idx, :).';
                end
                return;
            end

            if numel(s) == 3
                if s(1) >= idx
                    y = squeeze(data(idx, 1, :));
                elseif s(2) >= idx
                    y = squeeze(data(1, idx, :));
                end
                return;
            end
        end

        function v = lastValue(app, data)
            %#ok<INUSD>
            if isempty(data)
                v = 0;
                return;
            end

            data = squeeze(data);

            if isempty(data)
                v = 0;
            elseif isscalar(data)
                v = double(data);
            else
                v = double(data(end));
            end
        end

        function styleAxes(app, ax)
            ax.Color = [0.07 0.07 0.07];
            ax.XColor = [0.9 0.9 0.9];
            ax.YColor = [0.9 0.9 0.9];
            ax.GridColor = [0.35 0.35 0.35];
            ax.FontSize = 10;
            ax.Title.Color = [1 1 1];
        end

        function RunNominalButtonPushed(app, event)
            %#ok<INUSD>
            app.runScenario(0, 0, 'Nominal Flight');
        end

        function RunAltitudeSpoofButtonPushed(app, event)
            %#ok<INUSD>
            app.runScenario(1, 1, 'Altitude Spoofing');
        end

        function RunAirDataSpoofButtonPushed(app, event)
            %#ok<INUSD>
            app.runScenario(1, 2, 'Air-Data Spoofing');
        end

        function RunCoordinatedAttackButtonPushed(app, event)
            %#ok<INUSD>
            app.runScenario(1, 3, 'Coordinated False-Climb Attack');
        end

        function StopButtonPushed(app, event)
            %#ok<INUSD>
            try
                if bdIsLoaded(app.ModelName)
                    simStatus = get_param(app.ModelName,'SimulationStatus');
                    if ~strcmp(simStatus,'stopped')
                        set_param(app.ModelName,'SimulationCommand','stop');
                    end
                end
                app.ScenarioLabel.Text = 'Scenario: Stopped';
            catch ME
                uialert(app.UIFigure, ME.message, 'Stop Simulation Error');
            end
        end

        function RefreshButtonPushed(app, event)
            %#ok<INUSD>
            if isempty(app.LastSimOut)
                uialert(app.UIFigure, 'No simulation has been run yet.', 'No Data');
            else
                app.updateDashboard(app.LastSimOut);
            end
        end
    end

    methods (Access = private)

        function createComponents(app)

            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Color = [0.10 0.10 0.10];
            app.UIFigure.Position = [50 50 1350 760];
            app.UIFigure.Name = 'Cyber-Physical Integrity Dashboard';
            app.UIFigure.Theme = 'dark';

            % Header
            app.HeaderPanel = uipanel(app.UIFigure);
            app.HeaderPanel.Position = [15 685 1320 60];
            app.HeaderPanel.BackgroundColor = [0.02 0.07 0.12];

            app.TitleLabel = uilabel(app.HeaderPanel);
            app.TitleLabel.Text = 'CYBER-PHYSICAL INTEGRITY MONITOR';
            app.TitleLabel.FontSize = 24;
            app.TitleLabel.FontWeight = 'bold';
            app.TitleLabel.FontColor = [0.75 0.92 1.00];
            app.TitleLabel.Position = [20 20 520 30];

            app.SubtitleLabel = uilabel(app.HeaderPanel);
            app.SubtitleLabel.Text = 'Digital Twin Verification | Consistency Monitor | Resilient Autonomy Mode';
            app.SubtitleLabel.FontSize = 13;
            app.SubtitleLabel.FontColor = [0.85 0.85 0.85];
            app.SubtitleLabel.Position = [560 20 620 25];

            % Status Panel
            app.StatusPanel = uipanel(app.UIFigure);
            app.StatusPanel.Title = 'Cockpit-Style Status';
            app.StatusPanel.FontWeight = 'bold';
            app.StatusPanel.ForegroundColor = [1 1 1];
            app.StatusPanel.BackgroundColor = [0.13 0.13 0.13];
            app.StatusPanel.Position = [15 530 1320 145];

            app.CyberStatusLabel = uilabel(app.StatusPanel);
            app.CyberStatusLabel.Text = 'CYBER ATTACK STATUS';
            app.CyberStatusLabel.FontWeight = 'bold';
            app.CyberStatusLabel.FontColor = [1 1 1];
            app.CyberStatusLabel.Position = [25 85 180 22];

            app.NormalLamp = uilamp(app.StatusPanel);
            app.NormalLamp.Position = [35 55 24 24];
            app.NormalLamp.Color = [0 0.8 0];

            app.NormalLampLabel = uilabel(app.StatusPanel);
            app.NormalLampLabel.Text = 'NORMAL';
            app.NormalLampLabel.FontColor = [1 1 1];
            app.NormalLampLabel.Position = [65 55 75 22];

            app.AttackLamp = uilamp(app.StatusPanel);
            app.AttackLamp.Position = [35 25 24 24];
            app.AttackLamp.Color = [0.25 0.25 0.25];

            app.AttackLampLabel = uilabel(app.StatusPanel);
            app.AttackLampLabel.Text = 'ATTACK DETECTED';
            app.AttackLampLabel.FontColor = [1 1 1];
            app.AttackLampLabel.Position = [65 25 140 22];

            app.RAMStatusLabel = uilabel(app.StatusPanel);
            app.RAMStatusLabel.Text = 'RAM STATUS';
            app.RAMStatusLabel.FontWeight = 'bold';
            app.RAMStatusLabel.FontColor = [1 1 1];
            app.RAMStatusLabel.Position = [250 85 120 22];

            app.RAMStandbyLamp = uilamp(app.StatusPanel);
            app.RAMStandbyLamp.Position = [255 55 24 24];
            app.RAMStandbyLamp.Color = [0 0.8 0];

            app.RAMStandbyLampLabel = uilabel(app.StatusPanel);
            app.RAMStandbyLampLabel.Text = 'STANDBY';
            app.RAMStandbyLampLabel.FontColor = [1 1 1];
            app.RAMStandbyLampLabel.Position = [285 55 80 22];

            app.RAMActiveLamp = uilamp(app.StatusPanel);
            app.RAMActiveLamp.Position = [255 25 24 24];
            app.RAMActiveLamp.Color = [0.25 0.25 0.25];

            app.RAMActiveLampLabel = uilabel(app.StatusPanel);
            app.RAMActiveLampLabel.Text = 'ACTIVE';
            app.RAMActiveLampLabel.FontColor = [1 1 1];
            app.RAMActiveLampLabel.Position = [285 25 80 22];

            app.RAMBlendGaugeLabel = uilabel(app.StatusPanel);
            app.RAMBlendGaugeLabel.Text = 'TRUSTED STATE TRANSFER (%)';
            app.RAMBlendGaugeLabel.FontWeight = 'bold';
            app.RAMBlendGaugeLabel.FontColor = [1 1 1];
            app.RAMBlendGaugeLabel.Position = [450 85 230 22];

            app.RAMBlendGauge = uigauge(app.StatusPanel, 'linear');
            app.RAMBlendGauge.Position = [450 35 270 45];
            app.RAMBlendGauge.Limits = [0 100];
            app.RAMBlendGauge.Value = 0;

            app.CyberFlagDisplayLabel = uilabel(app.StatusPanel);
            app.CyberFlagDisplayLabel.Text = 'Cyber Flag';
            app.CyberFlagDisplayLabel.FontColor = [1 1 1];
            app.CyberFlagDisplayLabel.Position = [780 62 80 22];

            app.CyberFlagDisplay = uieditfield(app.StatusPanel, 'numeric');
            app.CyberFlagDisplay.Editable = 'off';
            app.CyberFlagDisplay.Position = [860 62 55 22];
            app.CyberFlagDisplay.Value = 0;

            app.RAMActiveDisplayLabel = uilabel(app.StatusPanel);
            app.RAMActiveDisplayLabel.Text = 'RAM Active';
            app.RAMActiveDisplayLabel.FontColor = [1 1 1];
            app.RAMActiveDisplayLabel.Position = [780 30 80 22];

            app.RAMActiveDisplay = uieditfield(app.StatusPanel, 'numeric');
            app.RAMActiveDisplay.Editable = 'off';
            app.RAMActiveDisplay.Position = [860 30 55 22];
            app.RAMActiveDisplay.Value = 0;

            app.TrustedStateLabel = uilabel(app.StatusPanel);
            app.TrustedStateLabel.Text = 'TRUSTED STATE SOURCE: MEASURED STATE';
            app.TrustedStateLabel.FontWeight = 'bold';
            app.TrustedStateLabel.FontSize = 14;
            app.TrustedStateLabel.FontColor = [0.4 1.0 0.4];
            app.TrustedStateLabel.Position = [970 55 330 35];

            % Control Panel
            app.ControlPanel = uipanel(app.UIFigure);
            app.ControlPanel.Title = 'Demo Scenario Control';
            app.ControlPanel.FontWeight = 'bold';
            app.ControlPanel.ForegroundColor = [1 1 1];
            app.ControlPanel.BackgroundColor = [0.13 0.13 0.13];
            app.ControlPanel.Position = [15 460 1320 60];

            app.ScenarioLabel = uilabel(app.ControlPanel);
            app.ScenarioLabel.Text = 'Scenario: Not Run';
            app.ScenarioLabel.FontColor = [1 1 1];
            app.ScenarioLabel.FontWeight = 'bold';
            app.ScenarioLabel.Position = [20 10 210 25];

            app.ModelLabel = uilabel(app.ControlPanel);
            app.ModelLabel.Text = 'Model: FYI_Twin_CyberResilient';
            app.ModelLabel.FontColor = [0.8 0.8 0.8];
            app.ModelLabel.Position = [240 10 250 25];

            app.StopTimeFieldLabel = uilabel(app.ControlPanel);
            app.StopTimeFieldLabel.Text = 'Stop Time';
            app.StopTimeFieldLabel.FontColor = [1 1 1];
            app.StopTimeFieldLabel.Position = [500 10 70 25];

            app.StopTimeField = uieditfield(app.ControlPanel, 'numeric');
            app.StopTimeField.Position = [570 12 65 22];
            app.StopTimeField.Value = 300;

            app.RunNominalButton = uibutton(app.ControlPanel, 'push');
            app.RunNominalButton.Text = 'Run Nominal';
            app.RunNominalButton.Position = [665 10 110 28];
            app.RunNominalButton.ButtonPushedFcn = createCallbackFcn(app, @RunNominalButtonPushed, true);

            app.RunAltitudeSpoofButton = uibutton(app.ControlPanel, 'push');
            app.RunAltitudeSpoofButton.Text = 'Altitude Spoof';
            app.RunAltitudeSpoofButton.Position = [785 10 115 28];
            app.RunAltitudeSpoofButton.ButtonPushedFcn = createCallbackFcn(app, @RunAltitudeSpoofButtonPushed, true);

            app.RunAirDataSpoofButton = uibutton(app.ControlPanel, 'push');
            app.RunAirDataSpoofButton.Text = 'Air-Data Spoof';
            app.RunAirDataSpoofButton.Position = [910 10 115 28];
            app.RunAirDataSpoofButton.ButtonPushedFcn = createCallbackFcn(app, @RunAirDataSpoofButtonPushed, true);

            app.RunCoordinatedAttackButton = uibutton(app.ControlPanel, 'push');
            app.RunCoordinatedAttackButton.Text = 'Coordinated Attack';
            app.RunCoordinatedAttackButton.Position = [1035 10 145 28];
            app.RunCoordinatedAttackButton.ButtonPushedFcn = createCallbackFcn(app, @RunCoordinatedAttackButtonPushed, true);

            app.StopButton = uibutton(app.ControlPanel, 'push');
            app.StopButton.Text = 'Stop';
            app.StopButton.Position = [1190 10 55 28];
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @StopButtonPushed, true);

            app.RefreshButton = uibutton(app.ControlPanel, 'push');
            app.RefreshButton.Text = 'Refresh';
            app.RefreshButton.Position = [1250 10 65 28];
            app.RefreshButton.ButtonPushedFcn = createCallbackFcn(app, @RefreshButtonPushed, true);

            % Plot Panel
            app.PlotPanel = uipanel(app.UIFigure);
            app.PlotPanel.Title = 'Consistency Monitor Graphs';
            app.PlotPanel.FontWeight = 'bold';
            app.PlotPanel.ForegroundColor = [1 1 1];
            app.PlotPanel.BackgroundColor = [0.10 0.10 0.10];
            app.PlotPanel.Position = [15 15 1320 435];

            app.ResidualAxes = uiaxes(app.PlotPanel);
            app.ResidualAxes.Position = [20 225 620 180];
            app.styleAxes(app.ResidualAxes);
            title(app.ResidualAxes, 'Consistency Residual: Raw vs Post-RAM');
            xlabel(app.ResidualAxes, 'Time (s)');
            ylabel(app.ResidualAxes, 'Residual Norm');

            app.AltitudeAxes = uiaxes(app.PlotPanel);
            app.AltitudeAxes.Position = [675 225 620 180];
            app.styleAxes(app.AltitudeAxes);
            title(app.AltitudeAxes, 'Altitude Channel');
            xlabel(app.AltitudeAxes, 'Time (s)');
            ylabel(app.AltitudeAxes, 'Altitude (m)');

            app.PitchAxes = uiaxes(app.PlotPanel);
            app.PitchAxes.Position = [20 20 620 180];
            app.styleAxes(app.PitchAxes);
            title(app.PitchAxes, 'Pitch Channel');
            xlabel(app.PitchAxes, 'Time (s)');
            ylabel(app.PitchAxes, '\theta (deg)');

            app.SelectedResidualAxes = uiaxes(app.PlotPanel);
            app.SelectedResidualAxes.Position = [675 20 620 180];
            app.styleAxes(app.SelectedResidualAxes);
            title(app.SelectedResidualAxes, 'Selected Physics Residuals');
            xlabel(app.SelectedResidualAxes, 'Time (s)');
            ylabel(app.SelectedResidualAxes, 'Residual');

            app.UIFigure.Visible = 'on';
        end
    end

    methods (Access = public)

        function pushLivePacket(app, packet)
            % Live update called from Simulink through FYI_DashboardPush.m.
            %
            % Packet order:
            % 1      time
            % 2      residual_norm
            % 3      post_RAM_residual_norm
            % 4      cyber_flag
            % 5      RAM_active
            % 6      ram_blend
            % 7:18   x_meas_attacked
            % 19:30  x_pred_unified
            % 31:42  x_safe
            % 43:54  x_true_unified
            % 55:62  residual_selected

            packet = double(packet(:));

            if numel(packet) < 62
                return;
            end

            tNow         = packet(1);
            rawResidual  = packet(2);
            postResidual = packet(3);
            cyberFlag    = packet(4);
            ramActive    = packet(5);
            ramBlend     = packet(6);

            idx = 7;
            xMeas = packet(idx:idx+11); idx = idx + 12;
            xPred = packet(idx:idx+11); idx = idx + 12;
            xSafe = packet(idx:idx+11); idx = idx + 12;
            xTrue = packet(idx:idx+11); idx = idx + 12;
            residualSelected = packet(idx:idx+7);

            app.LiveTime(end+1,1) = tNow;

            app.LiveRawResidual(end+1,1)  = rawResidual;
            app.LivePostResidual(end+1,1) = postResidual;
            app.LiveCyberFlag(end+1,1)    = cyberFlag;
            app.LiveRAMActive(end+1,1)    = ramActive;
            app.LiveRAMBlend(end+1,1)     = ramBlend;

            app.LiveAltitudeMeas(end+1,1) = xMeas(12);
            app.LiveAltitudePred(end+1,1) = xPred(12);
            app.LiveAltitudeSafe(end+1,1) = xSafe(12);
            app.LiveAltitudeTrue(end+1,1) = xTrue(12);

            app.LivePitchMeas(end+1,1) = rad2deg(xMeas(5));
            app.LivePitchPred(end+1,1) = rad2deg(xPred(5));
            app.LivePitchSafe(end+1,1) = rad2deg(xSafe(5));
            app.LivePitchTrue(end+1,1) = rad2deg(xTrue(5));

            app.LiveSelectedResidual(end+1,1:8) = residualSelected(:).';

            app.setAttackState(cyberFlag, ramActive, ramBlend);

            % Residual plot
            cla(app.ResidualAxes);
            hold(app.ResidualAxes, 'on');
            
            plot(app.ResidualAxes, app.LiveTime, app.LiveRawResidual, ...
                'LineWidth', 1.8, ...
                'DisplayName', 'Raw consistency residual');
            
            plot(app.ResidualAxes, app.LiveTime, app.LivePostResidual, '--', ...
                'LineWidth', 1.8, ...
                'DisplayName', 'Post-RAM residual');
            
            % Detection threshold line
            residual_norm_threshold = 30;
            
            plot(app.ResidualAxes, app.LiveTime, ...
                residual_norm_threshold * ones(size(app.LiveTime)), ':', ...
                'LineWidth', 1.8, ...
                'DisplayName', 'Detection threshold = 30');
            
            hold(app.ResidualAxes, 'off');
            grid(app.ResidualAxes, 'on');
            
            title(app.ResidualAxes, 'Consistency Residual: Raw vs Post-RAM');
            xlabel(app.ResidualAxes, 'Time (s)');
            ylabel(app.ResidualAxes, 'Residual Norm');
            
            legend(app.ResidualAxes, 'show', ...
                'TextColor', 'white', ...
                'Location', 'northeast');
            
            tFinal = app.StopTimeField.Value;
            if isempty(tFinal) || ~isfinite(tFinal) || tFinal <= 0
                tFinal = 60;
            end
            xlim(app.ResidualAxes, [0 tFinal]);
            ylim(app.ResidualAxes, [0 60]);
            
            % % Residual plot
            % cla(app.ResidualAxes);
            % hold(app.ResidualAxes, 'on');
            % plot(app.ResidualAxes, app.LiveTime, app.LiveRawResidual, ...
            %     'LineWidth', 1.8, 'DisplayName', 'Raw consistency residual');
            % plot(app.ResidualAxes, app.LiveTime, app.LivePostResidual, '--', ...
            %     'LineWidth', 1.8, 'DisplayName', 'Post-RAM residual');
            % hold(app.ResidualAxes, 'off');
            % grid(app.ResidualAxes, 'on');
            % title(app.ResidualAxes, 'Consistency Residual: Raw vs Post-RAM');
            % xlabel(app.ResidualAxes, 'Time (s)');
            % ylabel(app.ResidualAxes, 'Residual Norm');
            % legend(app.ResidualAxes, 'show', 'TextColor', 'white', 'Location', 'northeast');
            % app.fitAxisToData(app.ResidualAxes);

            % Altitude plot
            cla(app.AltitudeAxes);
            hold(app.AltitudeAxes, 'on');
            plot(app.AltitudeAxes, app.LiveTime, app.LiveAltitudeTrue, ...
                'LineWidth', 1.2, 'DisplayName', 'True');
            plot(app.AltitudeAxes, app.LiveTime, app.LiveAltitudeMeas, ...
                'LineWidth', 1.2, 'DisplayName', 'Measured/Attacked');
            plot(app.AltitudeAxes, app.LiveTime, app.LiveAltitudePred, ...
                'LineWidth', 1.2, 'DisplayName', 'Twin Predicted');
            plot(app.AltitudeAxes, app.LiveTime, app.LiveAltitudeSafe, '--', ...
                'LineWidth', 1.8, 'DisplayName', 'RAM Safe');
            hold(app.AltitudeAxes, 'off');
            grid(app.AltitudeAxes, 'on');
            title(app.AltitudeAxes, 'Altitude Channel: True / Attacked / Twin / RAM-Safe');
            xlabel(app.AltitudeAxes, 'Time (s)');
            ylabel(app.AltitudeAxes, 'Altitude (m)');
            legend(app.AltitudeAxes, 'show', 'TextColor', 'white', 'Location', 'best');
            tFinal = app.StopTimeField.Value;
            if isempty(tFinal) || ~isfinite(tFinal) || tFinal <= 0
                tFinal = 60;
            end
            xlim(app.AltitudeAxes, [0 tFinal]);
            ylim(app.AltitudeAxes, [0 250]);

            % Pitch plot
            cla(app.PitchAxes);
            hold(app.PitchAxes, 'on');
            plot(app.PitchAxes, app.LiveTime, app.LivePitchTrue, ...
                'LineWidth', 1.2, 'DisplayName', 'True');
            plot(app.PitchAxes, app.LiveTime, app.LivePitchMeas, ...
                'LineWidth', 1.2, 'DisplayName', 'Measured/Attacked');
            plot(app.PitchAxes, app.LiveTime, app.LivePitchPred, ...
                'LineWidth', 1.2, 'DisplayName', 'Twin Predicted');
            plot(app.PitchAxes, app.LiveTime, app.LivePitchSafe, '--', ...
                'LineWidth', 1.8, 'DisplayName', 'RAM Safe');
            hold(app.PitchAxes, 'off');
            grid(app.PitchAxes, 'on');
            title(app.PitchAxes, 'Pitch Channel: True / Attacked / Twin / RAM-Safe');
            xlabel(app.PitchAxes, 'Time (s)');
            ylabel(app.PitchAxes, '\theta (deg)');
            legend(app.PitchAxes, 'show', 'TextColor', 'white', 'Location', 'best');
            tFinal = app.StopTimeField.Value;
            if isempty(tFinal) || ~isfinite(tFinal) || tFinal <= 0
                tFinal = 60;
            end
            xlim(app.PitchAxes, [0 tFinal]);
            ylim(app.PitchAxes, [-15 15]);

            % Selected residuals
            cla(app.SelectedResidualAxes);
            hold(app.SelectedResidualAxes, 'on');
            labels = { ...
                'u residual (m/s)', ...
                'w residual (m/s)', ...
                '\theta residual (rad)', ...
                'q residual (rad/s)', ...
                'h residual (m)', ...
                '\phi residual (rad)', ...
                'p residual (rad/s)', ...
                'r residual (rad/s)'};

            for k = 1:8
                plot(app.SelectedResidualAxes, app.LiveTime, app.LiveSelectedResidual(:,k), ...
                    'LineWidth', 1.1, 'DisplayName', labels{k});
            end

            hold(app.SelectedResidualAxes, 'off');
            grid(app.SelectedResidualAxes, 'on');
            title(app.SelectedResidualAxes, 'Selected Physics Consistency Residuals');
            xlabel(app.SelectedResidualAxes, 'Time (s)');
            ylabel(app.SelectedResidualAxes, 'Residual');
            legend(app.SelectedResidualAxes, 'show', 'TextColor', 'white', 'Location', 'northeastoutside');
            tFinal = app.StopTimeField.Value;
            if isempty(tFinal) || ~isfinite(tFinal) || tFinal <= 0
                tFinal = 60;
            end
            xlim(app.SelectedResidualAxes, [0 tFinal]);
            ylim(app.SelectedResidualAxes, [0 60]);

            drawnow limitrate;
        end


        function app = FYICyberDashboard
            createComponents(app);
            startupFcn(app);

            % Register the running dashboard for FYI_DashboardPush.m
            assignin('base','FYI_DASHBOARD_APP',app);

            registerApp(app, app.UIFigure);

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end
end