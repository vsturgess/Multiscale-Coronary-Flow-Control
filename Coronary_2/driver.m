% Driver that runs the forward perfusion model 

clear all
%close all

printfigs_on = 0; % print plotted figures if printfigs_on = 1
autoregulation_on = 0; % turn autoregulation on = 1 

%% Load data and parameters 

load OSS_1150_data.mat 

% Scale flows, volumes, and compliances based on LV weight 
scale = 100 / Data.LVweight;

data            = Data.BL; 
data.scale      = scale; 
data.dt         = mean(diff(data.Time)); 
data.Q_myo      = data.Q_myo      / 60 * scale; 
data.Q_myo_M    = data.Q_myo_M    / 60 * scale; 
data.Q_myo_m    = data.Q_myo_m    / 60 * scale; 
data.Q_myo_base = data.Q_myo_base / 60 * scale; 
data.Q_myo_bar  = data.Q_myo_bar  / 60 * scale; 

% Parameter structure for the perfusion model and the representative vessel
% model for the epi, mid, and end layers 
pars = parameters(data); 

% Set level of exercise 
data.Exercise_LvL = 1.00; % 1.00 means no exercise, MVO2 remains unchanged
MVO2              = 60; % Rest MVO2
data.MVO2         = data.Exercise_LvL * MVO2; 

%% Run the model 

% Solve the perfusion model 
outputs = model_sol_perfusion(pars,data); 

% Compute initial mean penetrating artery flow 
Q_PA_1     = outputs.Q_PA; 
i_4per     = outputs.i_4per; 
Q_PA_1_bar = mean(Q_PA_1(i_4per)); 

% Compute initial Endo/Epi ratio 
Qa_epi_bar = outputs.epi.Qa_bar; 
Qa_end_bar = outputs.end.Qa_bar; 
disp(['Endo/Epi = ', num2str(Qa_end_bar/Qa_epi_bar)])

%% Autoregulate  

if autoregulation_on == 1

    ndone = 0; 
    k = 1; 
    while ndone == 0 
        
        % Run the representative vessel model with the outputs from the
        % initial perfusion model 
        outputs = model_sol_repvessel(pars,data,outputs); 
    
        % Recompute compliances based on vessel diameters 
        pars = reassigncompliances(pars,data,outputs); 
    
        % Run perfusion model with current perfusion model parameters 
        outputs = model_sol_perfusion(pars,data); 
    
        % Compute current mean penetrating artery flow 
        Q_PA_2     = outputs.Q_PA; 
        i_4per     = outputs.i_4per; 
        Q_PA_2_bar = mean(Q_PA_2(i_4per)); 
    
        % Compute error between previous and current mean Q_PA's
        err = abs(Q_PA_1_bar - Q_PA_2_bar); 
    
        % Stop criterion 
        if err < 1e-3 || k >= 100 
            ndone = 1;
        else 
            Q_PA_1_bar = Q_PA_2_bar; 
            k = k + 1; 
        end 
    end 
end 

% Compute final Endo/Epi ratio
Qa_epi_bar = outputs.epi.Qa_bar; 
Qa_end_bar = outputs.end.Qa_bar; 
disp(['Endo/Epi = ', num2str(Qa_end_bar/Qa_epi_bar)])

%% Vectors for figures 

scale = data.scale; 
Time  = data.Time; 
Q_myo = data.Q_myo * 60 / scale; 
P_LV  = data.P_LV; 
P_Ao  = data.P_Ao; 

% Scale flows to mL min^{-1}
Q_PA   = outputs.Q_PA   * 60 / scale; 
Qa_epi = outputs.epi.Qa * 60 / scale; 
Qa_mid = outputs.mid.Qa * 60 / scale; 
Qa_end = outputs.end.Qa * 60 / scale; 

P_PA   = outputs.P_PA; 
Pa_epi = outputs.epi.Pa; 
Pa_mid = outputs.mid.Pa;
Pa_end = outputs.end.Pa; 

%% Plot figures 

fontsize = 16; 

% Epi, mid, end flows 
hfig1 = figure(1); 
clf
hold on
h1 = plot(Time,Qa_epi,'r','LineWidth',2);
h2 = plot(Time,Qa_mid,'g','LineWidth',2);
h3 = plot(Time,Qa_end,'b','LineWidth',2);
xlim([Time(1) Time(end)])
xlabel('Time (s)')
ylabel('Myocardial Flow (mL min^{-1})')
set(gca,'Fontsize',fontsize)
legend([h1, h2, h3], 'Epi', 'Mid', 'End','location','northwest')

% Penetrating artery flow vs data 
hfig2 = figure(2);
clf
hold on
h1 = plot(Time,Q_myo,'k','linewidth',2);
h2 = plot(Time,Q_PA,'Color',[0 .75 .75],'linewidth',2);
ylabel('Myocardial Flow (mL min^{-1})')
xlabel('Time (s)')
set(gca,'Fontsize',fontsize)
xlim([Time(1) Time(end)])
legend([h1,h2],{'Data','Model'},'Location','northwest')

% Aortic and LV pressure data 
hfig3 = figure(3);
clf
hold on
h1 = plot(Time,P_Ao,'Color',[0 .5 1],'linewidth',1.5);
h2 = plot(Time,P_LV,'Color',[1 .5 0],'linewidth',1.5); 
ylabel('Pressure (mmHg)')
xlabel('Time (s)')
legend([h1, h2],'Aortic','LV','Location','southwest')
set(gca,'Fontsize',fontsize)
xlim([Time(1) Time(end)])
ylim([-10 max([P_Ao; P_LV])+10])

% Myocardial pressures 
hfig4 = figure(4);
clf
hold on
h1 = plot(Time,Pa_epi,'r','LineWidth',2);
h2 = plot(Time,Pa_mid,'g','LineWidth',2);
h3 = plot(Time,Pa_end,'b','LineWidth',2);
plot(Time,P_LV,'Color',[.8 .8 .8],'linewidth',1.5)
xlim([Time(1) Time(end)])
xlabel('Time (s)')
ylabel('Pressure (mmHg)')
legend([h1, h2, h3],'Epi','Mid','End','location','northwest')
set(gca,'Fontsize',fontsize)
ylim([min([Pa_epi; Pa_mid; Pa_end; P_LV])-10 max([Pa_epi; Pa_mid; Pa_end; P_LV])+10])

if printfigs_on == 1
    if k == 1 
        print(h1,'-dpng','~/Dropbox/UMICH/Coronary/Figures/LayerFlow_Control.png')
        print(hfig2,'-dpng','~/Dropbox/UMICH/Coronary/Figures/Flow_Control.png')
        print(hfig3,'-dpng','~/Dropbox/UMICH/Coronary/Figures/Pressure_Control.png')
        print(hfig4,'-dpng','~/Dropbox/UMICH/Coronary/Figures/LayerPressure_Control.png')
    elseif k == 2
        print(h1,'-dpng','~/Dropbox/UMICH/Coronary/Figures/LayerFlow_H1.png')
        print(hfig2,'-dpng','~/Dropbox/UMICH/Coronary/Figures/Flow_H1.png')
        print(hfig3,'-dpng','~/Dropbox/UMICH/Coronary/Figures/Pressure_H1.png')
        print(hfig4,'-dpng','~/Dropbox/UMICH/Coronary/Figures/LayerPressure_H1.png')
    elseif k == 3
        print(h1,'-dpng','~/Dropbox/UMICH/Coronary/Figures/LayerFlow_H2.png')
        print(hfig2,'-dpng','~/Dropbox/UMICH/Coronary/Figures/Flow_H2.png')
        print(hfig3,'-dpng','~/Dropbox/UMICH/Coronary/Figures/Pressure_H2.png')
        print(hfig4,'-dpng','~/Dropbox/UMICH/Coronary/Figures/LayerPressure_H2.png')
    else
        print(h1,'-dpng','~/Dropbox/UMICH/Coronary/Figures/LayerFlow_H3.png')
        print(hfig2,'-dpng','~/Dropbox/UMICH/Coronary/Figures/Flow_H3.png')
        print(hfig3,'-dpng','~/Dropbox/UMICH/Coronary/Figures/Pressure_H3.png')
        print(hfig4,'-dpng','~/Dropbox/UMICH/Coronary/Figures/LayerPressure_H3.png')
    end 
end 
