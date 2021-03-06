clear
%% libraries & path
do_preprocessing = 0;
do_postproc_erfplots = 0;
do_postproc_eyemovplots = 0;
do_postproc_univar = 0;
do_postproc_decode = 0;
do_postproc_univar_across = 0;
do_postproc_decode_across = 1;

do_postproc_univar_interactions = 0;
do_postproc_univar_interactions_across = 0;
do_sandbox = 0;
%% 
run_system = 'cfin_server';
switch run_system
    case 'jrking_laptop'
        cd('/media/DATA/Pro/Projects/Paris/Other/natmeg/')
        addpath('/media/DATA/Pro/Toolbox/fieldtrip/fieldtrip-20130225/');ft_defaults;
        addpath('/media/DATA/Pro/Toolbox/JR_toolbox/');
        addpath('/media/DATA/Pro/Toolbox/export_fig/');
        data_path = '/media/VSCOND_MEG/Arhus_data/tSSS/';
        output_path = data_path;
        events_path = '/media/VSCOND_MEG/Arhus_data/events.fif/';
        script_path = '/media/DATA/Pro/Projects/Paris/Other/natmeg/';
    case 'cfin_server'
        proj_home = '/projects/MINDLAB2013_01-MEG-AttentionEmotionVisualTracking/';
        proj_scratch = [proj_home, '/scratch/'];
        proj_scripts = [proj_home, '/scripts/'];
        script_path = [proj_scripts, 'kingjr/natmeg_arhus/'];
        cd(script_path)
        addpath('/usr/local/common/matlab_toolbox/fieldtrip/latest/');ft_defaults;
        %addpath('/opt/local/mne/share/matlab/') % this fails because FT
                                                 % has some old version of
                                                 % MNE that includes
                                                 % fiff_read_epochs...
        addpath('/projects/MINDLAB2013_01-MEG-AttentionEmotionVisualTracking/scripts/kingjr/natmeg_arhus/JR_toolbox/');
        addpath('/projects/MINDLAB2013_01-MEG-AttentionEmotionVisualTracking/scripts/git/export_fig/');
        %addpath('/media/DATA/Pro/Toolbox/export_fig/');
        data_path = [proj_scratch, '/tsss_initial/'];
        events_path = [proj_scratch, '/events.fif/'];
        output_path = [proj_scratch, '/matlab/'];
end

% generic functions
get_trials = @(x) reshape(cell2mat(x.trial),[size(x.trial{1}) length(x.trial)]); % fast way of getting ft_trials
get_selTrials = @(x,sel) reshape(cell2mat(x.trial(sel)),[size(x.trial{1}) length(find(sel))]); % fast way of getting ft_trials
get_meanTrials = @(x,sel) trimmean(reshape(cell2mat(x.trial(sel)),[size(x.trial{1}) length(find(sel))]),90,'round',3); 
selchan = @(c,s) find(cell2mat(cellfun(@(x) ~isempty(strfind(x,s)),c,'uniformoutput', false))==1); % fast way of selecting ft_channel

%% GENERAL SETUP
experiment_info;
% list subject names
files = dir(data_path);
subjects = [];
for ii = 1:length(files)
    % if not hidden folder
    if files(ii).isdir && ~strcmp(files(ii).name(1), '.')
        subject.name = files(ii).name;
        
        % find meg files
        subfile             = dir([data_path subject.name '/FFA*tsss*.fif']);
        subject.file_ffa    = [data_path subject.name '/' subfile.name];
        
        subfile             = dir([data_path subject.name '/VS*1_tsss*.fif']);
        subject.file_vs1    = [data_path subject.name '/' subfile.name];
        
        subfile             = dir([data_path subject.name '/VS*2_tsss*.fif']);
        subject.file_vs2    = [data_path subject.name '/' subfile.name];
        
        subfile             = dir([data_path subject.name '/empty_room_tsss.fif']);
        subject.file_empty  = [data_path subject.name '/' subfile.name];
        
        % find corrected events (the original were misaligned. Contact
        % Arthus for more info)
        subfile                 = dir([events_path subject.name '/raw/FFA-eve.fif']);
        subject.file_ffa_event  = [events_path subject.name '/raw/' subfile.name(1:(end-4))];
        
        subfile                 = dir([events_path subject.name '/raw/VS_1*_1-eve*.fif']);
        subject.file_vs1_event  = [events_path subject.name '/raw/' subfile.name(1:(end-4))];
        
        subfile                 = dir([events_path subject.name '/raw/VS_1*_2-eve*.fif']);
        subject.file_vs2_event  = [events_path subject.name '/raw/' subfile.name(1:(end-4))];
        
        % create directories
        folder = [output_path 'erf/' subject.name];
        if ~exist(folder, 'dir');
            mkdir(folder);
        end
        folder = [output_path 'mvpas/' subject.name];
        if ~exist(folder, 'dir');
            mkdir(folder);
        end
        
        % save subject's details
        if isempty(subjects)
            subjects = subject;
        else
            subjects(end+1) = subject;
        end
        clear subject
    end
end
if ~exist([output_path 'erf/across_subjects/'],'dir')
    mkdir([output_path 'erf/across_subjects/']);
end
    
clear files ii jj subfile

analyses = {'visualSearch', 'feedback'};
%analyses = {'visualSearch'}; % for the trialinfo fix we only need to re-run 
                             % visualSearch, as the feedback trialdefs were
                             % OK.
%analyses = {'feedback'};

%% add information about subjects' conditioning order (scenario)
subjects_names = {'005_ELX','006_HEN','007_SGF','008_LFI',...
'009_7XF','010_6FP','011_U8G','012_GCX',...
'013_YG1','014_FUB','015_MYS','016_YV7',...
'017_PLX','018_9O3','019_VQF','020_4TZ',...
'021_LHM','022_U9F','023_Q4V','024_FMS',...
'025_DOJ','026_ONE','027_JTJ','028_VRR',...
'029_H0O','030_WAH'};
% the names don't match so we'll ujust use subjects' numbers
subjects_names = cellfun(@(x) x(1:3), subjects_names,'uniformoutput',false);
subjects_scenario = [1,2,1,2,1,2,1,2,1,2,1,1,2,1,2,1,2,1,2,1,2,1,2,1,2,2]; % A=1 B=2
for s = length(subjects):-1:1
    index = find(ismember(subjects_names, subjects(s).name(1:3)));
    if ~isempty(index)
        subjects(s).scenario = subjects_scenario(index);
    else
        subjects(s).name
    end
end

%% PREPROCESSING
if do_preprocessing,
    for analysis = analyses
        analysis = analysis{1}; 
        for subject = subjects
            
            switch analysis
                case 'visualSearch'
                    files = {...
                        subject.file_vs1, subject.file_vs1_event; % pre conditioning
                        subject.file_vs2, subject.file_vs2_event; % post conditioning
                        subject.file_ffa, subject.file_ffa_event};% FFA post conditioning
                case 'feedback' 
                    files = {...
                        subject.file_vs1, subject.file_vs1_event; % pre conditioning
                        subject.file_vs2, subject.file_vs2_event};% post conditioning
            end
            
            for condition = 1:length(files) % vs1 vs2 ffa
                %% get event values
                data_file   = files{condition,1};
                events_file = files{condition,2};
                
                % get file header
                header      = ft_read_header(data_file);
                
                % retrieve corrected triggers (see MNE script); note that fif files
                % don't necessarily start at sample=0, and that fieldtrip doesn't
                % tell you were the original first_sample started
                system(['python ' script_path 'get_events.py ' data_file ' ' events_file '.fif']);
                
                %% define trials
                clear events
                load([events_file '.mat'], 'events');
                events = double(events);
                
                % mannually define trials
                switch analysis
                    case 'visualSearch'
                        sel     = events(:,3)>=100;               % only keep stimulus triggers
                    case 'feedback'
                        sel     = events(:,3)>=10 & events(:,3)<=21; % feedback 10 11 20 21
                end
                cfg     = [];
                % CJB: this is where the "mysterious" time shift occurs!
                % the cfg.trl structure is an Nx4 array, with columns:
                % [begtrial, endtrial, OFFSET, trigval]
                % ADD: fixed offset of -500 ms
                cfg.trl = cat(2,...
                    events(sel,1) - header.Fs*0.500, ...% start trial 500 ms before stimulus onset to get a nice baseline
                    events(sel,1) + header.Fs*1.500, ...% end 1.500 s after stimulus onset
                    -0.500*header.Fs*ones(size(events(sel,1))), ...  % fixed pre-stim offset of -500 ms
                    events(sel,3));                       % trigger value
                
                % check that none of the trials exceed recording
                sel     = find(cfg.trl(:,1)<=0 | cfg.trl(:,2)>header.nSamples);
                
                if ~isempty(sel),
                    warning('%i trials definition exceeds the recording!', length(sel));
                end
                cfg.trl(sel ,:) = [];
                clear sel events
                
                if 0
                    %% check photodio timing
                    cfg_                = cfg;
                    cfg_.datafile       = data_file;
                    cfg_.header         = header;
                    cfg_.feedback       = 'gui';
                    cfg_.channel        = selchan(header.label,'MISC001');
                    data_               = ft_preprocessing(cfg_);
                    photodiod           = squeeze(get_trials(data_));
                    imagesc(photodiod')
                end
                
                %% preprocessing
                cfg.datafile        = data_file;
                cfg.header          = header;
                cfg.feedback        = 'gui';
                cfg.bpfilter        = 'yes';
                cfg.bpfreq          = [.5 35];  % band pass filter between .5 and 35 Hz
                cfg.demean          = 'yes';    % baseline correction on pre stimulus

                % HERE BE DRAGONS: with the above fix for the offset, this
                % needs to be relative to the new (-500 ms offset) times!
                cfg.baselinewindow  = [-0.4 -0.1];% I'll just assume this [0 .300]; corresponds to [-0.4, -0.1] in the new scale
                data                = ft_preprocessing(cfg);
                
                %% CJB: redoing the trial info, 
                %  remove the offset-column since everything below is
                %  hard-coded to column 3 being the trigger value!
                cfg.trl(:, 3) = [];
                data.trialinfo      = cfg.trl;  % fieldtrip loses this field, so readd it
                
                %% redefine trial according to onset of critical stimulus
                % CJB: This is no longer needed due to the offset being
                % included in cfg.trl above
                %cfg         = [];
                
                %cfg.offset  = -(.500+.100) * data.fsample ; % Here: not sure why the trials starts at .100 s in the visual search task but not in the feedback

                
                %data        = ft_redefinetrial(cfg,data);
                
                                
                %% downsampling for faster first analysis
                disp('Resample...');
                cfg                    = [];
                cfg.resamplefs         = 250; %256;
                cfg.detrend            = 'no';
                cfg.feedback           = 'gui';
                %avoid resampling numerical errors
                for t = 1:length(data.time)
                    data.time{t}       = data.time{1};
                end
                data_resample          = ft_resampledata(cfg,data);
                %-- sample info adjustment
                data_resample          = ft_resample_datainfo(data,data_resample);
                
                data=data_resample;
                clear data_resample;
                
                %% build explicit trial info
                % this is wrong: the face 1 ('a', '3') vs face 2 ('b', '10') contrast
                % should be: round(val/100) > 1 (anything 1xx -> 0,
                % anything 2xx -> 1), AND the odd/identical contrast should
                % be testing against >0, not >1!
                data.trialinfo(:,7) = condition;
                switch analysis
                    case 'visualSearch'
                        %data.trialinfo(:,4) = mod(data.trialinfo(:,3),100)>1; % face 1 or face 2
                        data.trialinfo(:,4) = round(data.trialinfo(:,3)/100)>1; % face {1,'a','3'} or face {2,'b','10'}
                        
                        data.trialinfo(:,5) = mod(data.trialinfo(:,3),10)>0;  % odd or identical faces
                        data.trialinfo(:,6) = mod(data.trialinfo(:,3),10);    % position of odd ball
                    case 'feedback'
                        data.trialinfo(:,4) = data.trialinfo(:,3)>19;         % face 1 or 2
                        data.trialinfo(:,5) = mod(data.trialinfo(:,3),10)>0;  % odd or identical (emotion)
                end
                
                %{
        %% save preprocessing of each condition separately
        filename    = [data_path 'erf/' subject.name '/' data_file(1:(end-4)) '_erf'];
        dat         = reshape(cell2mat(data.trial),[size(data.trial{1}) length(data.trial)]);
        % save in binary to avoid stupid matlab unreasonable memory usage
        binsave([filename '.dat'],dat);
        % save feildtrip structure
        data.trial  = [filename '.dat'];
        data.dims   = size(dat);
        scripts     = getscripts(); % save scripts that generated the data;
        save([filename '.mat'], 'data', 'scripts');
        clear data scripts filename dat data_file
                %}
                
                datas{condition} = data;
                clear data dat filename dat data_file;
            end
            %% append all conidition into a single file
            data = ft_append_sampleinfo([],datas);
            clear datas
            
            %% save
            filename    = [output_path 'erf/' subject.name '/' subject.name '_' analysis '_erf'];
            dat         = reshape(cell2mat(data.trial),[size(data.trial{1}) length(data.trial)]);
            % save in binary to avoid unreasonable memory usage
            binsave([filename '.dat'],dat);
            % save feildtrip structure
            data.trial  = [filename '.dat'];
            data.dims   = size(dat);
            scripts     = getscripts(); % save scripts that generated the data;
            save([filename '.mat'], 'data', 'scripts');
            clear data scripts filename dat data_file
        end
    end
end
%% POSTPROCESSING: erf plots (this is wihtout comparison)
if do_postproc_erfplots
    for analysis = analyses
        analysis = analysis{1}; 
        for subject = subjects
            subject.name
            % select subject
            file = [output_path 'erf/' subject.name '/' subject.name '_' analysis '_erf'];
            data = ft_loadbin([file '.mat'],[file '.dat']);
            
            %% saving
            if ~exist([file '_mean.mat'],'file')
                copyfile([file '.mat'], [file '_mean.mat']);
            end
            
            %% check photo diod
            chan=selchan(data.label,'MISC001');% photodiod channel
            photodiod = cell2mat(cellfun(@(x) x(chan,:)',data.trial,'uniformoutput', false))';
            figure(3); clf; imagesc(data.time{1},[],photodiod);
            export_fig([file '_photodiod.png']);
            close all;
            save([file '_mean.mat'], 'photodiod', '-append');
            clear photodiod;
            
            %% check trigger: this is EXPECTED to be wrong (negative)!!
            chan=selchan(data.label,'STI101');% trigger channel
            figure(4); clf; trigger=cell2mat(cellfun(@(x) x(chan,:)',data.trial,'uniformoutput', false))';
            imagesc(data.time{1},[],trigger);
            export_fig([file '_trigger.png']);
            close all;
            save([file '_mean.mat'], 'trigger', '-append');
            clear trigger;
            
            %% BASIC ERF
            % plot all
            cfg             = [];
            cfg.save        = true;
            cfg.figure_name = [file '_all'];
            plot_all(data,cfg);
            %close all;
            erf_all = get_meanTrials(data,1:length(data.trial));
            save([file '_mean.mat'], 'erf_all', '-append');
            clear erf_all;
            
            % VS1
            cfg             = [];
            cfg.save        = true;
            cfg.figure_name = [file '_VS1'];
            cfg.trial       = data.trialinfo(:,7)==1;
            plot_all(data,cfg);
            %close all;
            erf_pre = get_meanTrials(data,cfg.trial);
            save([file '_mean.mat'], 'erf_pre', '-append');
            clear erf_pre;
            
            % VS2
            cfg             = [];
            cfg.save        = true;
            cfg.figure_name = [file '_VS2'];
            cfg.trial = data.trialinfo(:,7)==2;
            plot_all(data,cfg);
            %close all;
            erf_post = get_meanTrials(data,cfg.trial);
            save([file '_mean.mat'], 'erf_post', '-append');
            clear erf_post;
            
            % FFA, only if in visualSearch analysis
            switch analysis
                case 'visualSearch'
                    cfg             = [];
                    cfg.save        = true;
                    cfg.figure_name = [file '_FFA'];
                    cfg.trial       = data.trialinfo(:,7)==3;
                    plot_all(data,cfg);
                    %close all;
                    erf_ffa = get_meanTrials(data,cfg.trial);
                    save([file '_mean.mat'], 'erf_ffa', '-append');
                    clear erf_ffa;
            end
        end
    end
end    
%% POSTPROCESSING: erf plots of eye movements 
if do_postproc_eyemovplots
    for analysis = analyses
        analysis = analysis{1}; 
        for subject = subjects
            subject.name
            % select subject
            file = [output_path 'erf/' subject.name '/' subject.name '_' analysis '_erf'];
            data = ft_loadbin([file '.mat'],[file '.dat']);
            
            %% 
            pre=data.trialinfo(:,7)==1; post=data.trialinfo(:,7)==2;
            figure(3); clf; set(gcf,'color','w', 'Position', [559         128        1100        1031])
            chanlist = [2,5,3,6];
            for miscNo = 1:length(chanlist)
                curChan = sprintf('MISC00%d', chanlist(miscNo));
                chan=selchan(data.label,curChan);% X1
                mtrx = cell2mat(cellfun(@(x) x(chan,:)',data.trial,'uniformoutput', false))';
                subplot(5, 2, miscNo)
                imagesc(data.time{1},[],mtrx(pre,:)); set(gca,'CLim',[-5, 5]); hold on
                plot(data.time{1}, (mean(mtrx(pre,:),1)+1)*100,'k','LineWidth',2)
                subplot(5, 2, miscNo + 4 + 2)
                imagesc(data.time{1},[],mtrx(post,:)); set(gca,'CLim',[-5, 5]); hold on
                plot(data.time{1}, (mean(mtrx(post,:),1)+1)*100,'k','LineWidth',2)
            end
            subplot(5,2,5); text(0.7, 0.5, 'Left eye'); text(0.05, 0.7, 'PRE'); 
            text(0.05, 0.3, 'POST'); text(0.3, 0.8, 'X (sacc)'); text(0.3, 0.6, 'Y (blink)'); 
            text(0.3, 0.4, 'X (sacc)'); text(0.3, 0.2, 'Y (blink)'); colorbar; set(gca,'CLim',[-5, 5]); 
            subplot(5,2,6); text(0.7, 0.5, 'Right eye'); text(0.05, 0.7, 'PRE'); 
            text(0.05, 0.3, 'POST'); text(0.3, 0.8, 'X (sacc)'); text(0.3, 0.6, 'Y (blink)'); 
            text(0.3, 0.4, 'X (sacc)'); text(0.3, 0.2, 'Y (blink)'); colorbar; set(gca,'CLim',[-5, 5]);
            clear mtrx;
            export_fig_cjb([file '_eyemov_sessions.png']);

        end
    end
end    
%% POSTPROCESSING: univariate
if do_postproc_univar
    for analysis = analyses
        analysis = analysis{1};
        for subject = subjects
            % select subject
            file = [output_path 'erf/' subject.name '/' subject.name '_' analysis '_erf'];
            data = ft_loadbin([file '.mat'],[file '.dat']);
            
            % initialize result file
            if ~exist([file '_univariate.mat'], 'file')
                save([file '_univariate.mat'], 'subject');
            end
            
            %% Main effect contrasts
            contrasts = {'face', 'odd', 'prepost'};
            for contrast = contrasts
                contrast = contrast{1};
                % define contrast
                % the y vector (y being the predictor) is used to compared trials where
                % y==1 and trials where y==2.
                switch contrast
                    case 'face',
                        y = (1+(data.trialinfo(:,4))).*(data.trialinfo(:,7)<3);
                    case 'odd',
                        y = (1+data.trialinfo(:,5)).*(data.trialinfo(:,7)<3); % odd or identical faces in VS1 and VS2
                    case 'prepost'
                        y = data.trialinfo(:,7);
                        y(y==3)=0;
                end
                
                %----- compute contrast
                [data_erf data_p]= postproc_univariate(data,y);
                
                %----- plot contrast erf
                cfg             = [];
                cfg.zlim_grad   = [0 1]*5e-12;
                cfg.zlim_mag    = [-1 1]*5e-13;
                cfg.save        = true;
                cfg.figure_name = [file '_all_' contrast 'ERF'];
                plot_all(data_erf,cfg);
                
                %----- plot contrast p value
                cfg             = [];
                cfg.zlim_mag    = [0 6];
                cfg.zlim_grad   = [0 6]; % should change plotting function to avoid combination in case of p value.
                cfg.save        = true;
                cfg.figure_name = [file '_all_' contrast 'P'];
                plot_all(data_p,cfg);
                
                %----- save
                eval([contrast '.p=data_p']);
                eval([contrast '.erf=data_erf']);
                save([file '_univariate.mat'], contrast, '-append');
                clear(contrast);close all;
            end
            
            %% Interaction contrasts
            contrasts = {'faceXprepost','oddXprepost','CS+vsCS-'};
            % TO BE DONE
        end
    end
end
%% POSTPROCESSING: decoding
if do_postproc_decode
    for analysis = analyses
        analysis = analysis{1};
        
        for subject = subjects
            subject.name
            
            %% Main effect contrasts
            clear data; % free memory
            file = [output_path 'erf/' subject.name '/' subject.name '_' analysis '_erf'];
            load([file '.mat'],'data'); % load fieldtrip strcture (leave away binaries)
            
            contrasts = {'face', 'odd', 'prepost'};
            for contrast = contrasts
                contrast = contrast{1};
                % define contrast
                % the y vector (y being the predictor) is used to compared trials where
                % y==1 and trials where y==2.
                switch contrast
                    case 'face',
                        y = (1+(data.trialinfo(:,4))).*(data.trialinfo(:,7)<3);
                    case 'odd',
                        y = (1+data.trialinfo(:,5)).*(data.trialinfo(:,7)<3); % odd or identical faces in VS1 and VS2
                    case 'prepost'
                        y = data.trialinfo(:,7);
                        y(y==3)=0;
                end
                
                %----- decode
                cfg             = [];
                cfg.Xdim        = data.dims;
                cfg.transpose   = [2 0 1];
                cfg.features    = selchan(data.label,'MEG'); % which channels should be incorporated in the analysis
                cfg.dims        = find(data.time{1}>-.150,1):2:find(data.time{1}>.550,1); % which time point should the classifier be trained on
                cfg.namey       = contrast;
                cfg.path        = [output_path 'erf/' subject.name '/'];
                cfg.void        = false;
                results         = jr_classify([file '.dat'],y,cfg);
                %auc             = colAUC(squeeze(results.probas(:,:,:,1)), results.y);
                %plot(data.time{1}(cfg.dims),auc);
            end
            
            
            
            %% Generalization across conditions: train in pre on face, test in post
            contrasts = {'facePre', 'oddPre'};
            for contrast = contrasts
                contrast=contrast{1};
                switch contrast
                    case 'facePre'
                        % face1 vs face2 in pre generalize to post
                        y = (1+(data.trialinfo(:,4))); % train on face
                        y(data.trialinfo(:,7)==2)=-y(data.trialinfo(:,7)==2); % only on pre  and generalize on post
                        y(data.trialinfo(:,7)==3)=0;%don't use FFA localizer
                    case 'oddPre'
                        y = (1+data.trialinfo(:,5));% train on odd
                        y(data.trialinfo(:,7)==2)=-y(data.trialinfo(:,7)==2); % only on pre  and generalize on post
                        y(data.trialinfo(:,7)==3)=0;%don't use FFA localizer
                        
                end
                
                %----- decode
                cfg             = [];
                cfg.Xdim        = data.dims;
                cfg.transpose   = [2 0 1];
                cfg.features    = selchan(data.label,'MEG'); % which channels should be incorporated in the analysis
                cfg.dims        = find(data.time{1}>-.150,1):2:find(data.time{1}>.550,1); % which time point should the classifier be trained on
                cfg.namey       = contrast;
                cfg.path        = [output_path 'erf/' subject.name '/'];
                cfg.void        = false;
                results         = jr_classify([file '.dat'],y,cfg);
            end
            
        end
    end
end
%% POSTPROCESSING ERF across subjects
if do_postproc_univar_across
    conditions = {'erf_all', 'erf_pre', 'erf_post'};
    contrasts = {'face','odd', 'condition'};
    
    for analysis = analyses
        analysis = analysis{1};
        
        %% non contrastive ERF
        for condition = conditions
            condition = condition{1};
            %% concatenate data across subjects
            erf = {};
            for subject = subjects
                file = [output_path 'erf/' subject.name '/' subject.name '_' analysis '_erf_mean.mat'];
                data = load(file, condition);
                erf{end+1} = data.(condition);
            end
            % put in fieldtrip structure % this is messy, should be redone
            load([output_path 'erf/' subjects(1).name '/' subjects(1).name '_' analysis '_erf.mat'],'data')
            data = rmfield(data,{'trialinfo', 'sampleinfo', 'dims', 'cfg'});
            data.trial = erf;
            data.time = data.time(ones(length(subjects),1));
            data.label = data.label(1:306);
            %% plot ERF
            cfg             = [];
            cfg.toi         = -.020:.02:.200;
            cfg.tlim_timeXtrial = [-0.2 0.300];
            cfg.zlim_mag    = [-1 1]*1e-13;
            cfg.zlim_grad   = [0 1]*5e-12;
            cfg.save        = true;
            cfg.figure_name = [output_path 'erf/across_subjects/across_subjects_' analysis '_erf_' condition];
            plot_all(data,cfg);
        end
        close all;
        
        %% Contrasts
        contrasts = {'face', 'odd', 'prepost'};
        for contrast = contrasts
            contrast=contrast{1};
            %% concatenate data across subjects within a fieldtrip structure
            for s = 1:length(subjects)
                clear data
                file = [output_path 'erf/' subjects(s).name '/' subjects(s).name '_' analysis '_erf_univariate.mat'];
                data = load(file, contrast);
                if s == 1
                    all_erf = data.(contrast).erf;
                    all_p = data.(contrast).p;
                else
                    all_erf.trials{s} = data.(contrast).erf.trial{1};
                    all_p.trials{s} = data.(contrast).p.trial{1};
                end
            end
            
            %% plot ERF
            cfg             = [];
            cfg.toi         = -.030:.030:.250;
            cfg.tlim_timeXtrial = [-0.2 0.300];
            cfg.zlim_mag    = [-1 1]*1e-13;
            cfg.zlim_grad   = [0 3]*1e-12;
            cfg.save        = true;
            cfg.figure_name = [output_path 'erf/across_subjects/across_subjects_' analysis '_erf_' contrast 'ERF'];
            plot_all(all_erf,cfg);
            
            %% plot p values
            cfg             = [];
            cfg.toi         = -.030:.03:.250;
            cfg.tlim_timeXtrial = [-0.2 0.300];
            cfg.zlim_mag    = [0 6];
            cfg.zlim_grad   = [0 6];
            cfg.save        = true;
            cfg.figure_name = [output_path 'erf/across_subjects/across_subjects_' analysis '_erf_' contrast 'P'];
            plot_all(all_p,cfg);
        end
        close all;
    end
end
%% POSTPROCESSING DECODING across subjects
if do_postproc_decode_across
    conditions = {'erf_all', 'erf_pre', 'erf_post'};

    for analysis = analyses
        analysis=analysis{1};
        
        contrasts = {'face','odd', 'prepost'};
        for contrast= contrasts;
            contrast=contrast{1};
            %% concatenate decoding prediction
            auc =  [];
            for subject = subjects
                file = [output_path 'erf/' subject.name '/' subject.name '_' analysis '_erf_' contrast '_results.mat'];
                results=load(file,'probas','y','dims','features');
                auc(end+1,:) = colAUC(squeeze(results.probas(:,:,:,1,1)), results.y);
            end
            %% retrieve time
            load([output_path 'erf/' subject.name '/' subject.name '_' analysis '_erf.mat'],'data');
            time = data.time{1}(results.dims);
            clear data;
            xlim_man = [-0.15 0.3];
            %% plot
            fh=figure();set(gcf,'color','w');
            set(fh,'Renderer','painters')
            subplot(2,1,1);
            plot_eb(time,auc);
            axis tight;axis([xlim_man .45 1]);box off;hold on;plot(xlim_man,[.5 .5],'--k');colorbar;
            subplot(2,1,2);
            imagesc(time,[],auc,[0 1]);colorbar; set(gca, 'XLim', xlim_man);
            axis tight;box off;
            export_fig_cjb([output_path 'erf/across_subjects/across_subjects_' analysis '_erf_' contrast '_decoding.png']);
        end
        
        %% train in one condition generalize to the other
        contrasts={'facePre', 'oddPre'};
        for contrast = contrasts
            contrast = contrast{1};
            %% concatenate decoding prediction
            auc =  [];
            aucg=  [];
            for subject = subjects
                file = [output_path 'erf/' subject.name '/' subject.name '_' analysis '_erf_' contrast '_results.mat'];
                results=load(file,'probas','probasg', 'y','yg', 'dims','features');
                auc(end+1,:) = colAUC(squeeze(results.probas(:,:,:,1,1)), results.y);
                aucg(end+1,:) = colAUC(squeeze(results.probasg(:,:,:,1,1)), -results.yg);
            end
            %% retrieve time
            load([output_path 'erf/' subject.name '/' subject.name '_' analysis '_erf.mat'],'data');
            time = data.time{1}(results.dims);
            clear data;
            xlim_man = [-0.15 0.3];
            %% plot
            fh=figure();set(gcf,'color','w');
            set(fh,'Renderer','painters')
            subplot(2,1,1);
            plot_eb(time,auc,[0 0 1]);
            hold on;
            plot_eb(time,aucg,[1 0 0]);
            axis tight;axis([xlim_man .45 1]);box off;hold on;plot(xlim_man,[.5 .5],'--k');colorbar;
            subplot(4,1,3);
            imagesc(time,[],auc,[0 1]);colorbar;  set(gca, 'XLim', xlim_man);
            axis tight;box off;
            subplot(4,1,4);
            imagesc(time,[],aucg,[0 1]);colorbar;  set(gca, 'XLim', xlim_man);
            axis tight;box off;
            export_fig_cjb([output_path 'erf/across_subjects/across_subjects_' analysis '_erf_' contrast '_decoding_generalization.png']);
        end
    end
end


%% POSTPROCESSING: univariate interactions
if do_postproc_univar_interactions
    for analysis = analyses
        analysis = analysis{1};
        for subject = subjects
            % select subject
            file = [output_path 'erf/' subject.name '/' subject.name '_' analysis '_erf'];
            data = ft_loadbin([file '.mat'],[file '.dat']);
            
            %%
            if subject.scenario == 1,
                CSinfo = ~data.trialinfo(:,4);
            else
                CSinfo = data.trialinfo(:,4);
            end

            %% Interaction contrasts
            %contrasts = {'faceXprepost','oddXprepost','CS+vsCS-'};
            %contrasts = {'faceXodd', 'csXodd'};
            %contrasts = {'csXdevXses'};%, 
            contrasts = {'faceXodd', 'csXoddXses'}; % these are the interactions
                                                    % that make sense:
                                                    % 1) |DEV vs STD|_x_face
                                                    % 2) |DEV vs STD|_x_CS_x_session
            for contrast = contrasts
                contrast = contrast{1};
                % define contrast
                % the y vector (y being the predictor) is used to compared trials where
                % y==1 and trials where y==2.
                switch contrast
                    case 'faceXodd', % DEV vs STD resp differs dep. on identity?
                        y = (1+~xor(data.trialinfo(:,4), data.trialinfo(:,5))).*(data.trialinfo(:,7)<3);
                    case 'csXodd', % CS only makes sense when taken as _x_session 
                        y = (1+~xor(CSinfo, data.trialinfo(:,5))).*(data.trialinfo(:,7)<3); 
                    case 'csXdevXses' % this is turns out to be quite messy, so drop it!
                        CSp_dev = CSinfo.*data.trialinfo(:,5); % all CSp deviants
                        CSm_dev = (~CSinfo).*data.trialinfo(:,5); % all CSm deviants
                        postpre = data.trialinfo(:,7) - 1;
                        postpre(postpre==2) = 3; postpre(postpre==0) = 2; 
                        y = CSp_dev .* postpre;
                        y = y + CSm_dev .* data.trialinfo(:,7);
                    case 'csXoddXses'
                        y = xor(CSinfo, data.trialinfo(:,5));
                        y(data.trialinfo(:,7) < 2) = ~y(data.trialinfo(:,7) < 2);
                        y = y.*(data.trialinfo(:,7)<3); y = y + 1;
                end
                
                %----- compute contrast
                [data_erf data_p]= postproc_univariate(data,y);
                
                %----- plot contrast erf
                cfg             = [];
                cfg.zlim_grad   = [0 2]*1e-12;
                cfg.zlim_mag    = [-1 1]*1e-13;
                cfg.toi         = -.030:.030:.250;
                cfg.tlim_timeXtrial = [-0.2 0.300];
                cfg.save        = true;
                cfg.figure_name = [file '_all_' contrast 'ERF'];
                plot_all(data_erf,cfg);
                
                %----- plot contrast p value
                cfg             = [];
                cfg.zlim_mag    = [0 6];
                cfg.zlim_grad   = [0 6]; % should change plotting function to avoid combination in case of p value.
                cfg.toi         = -.030:.030:.250;
                cfg.tlim_timeXtrial = [-0.2 0.300];
                cfg.save        = true;
                cfg.figure_name = [file '_all_' contrast 'P'];
                plot_all(data_p,cfg);
                
                %----- save
                eval([contrast '.p=data_p']);
                eval([contrast '.erf=data_erf']);
                save([file '_univariate.mat'], contrast, '-append');
                clear(contrast);close all;
            end
            
        end
    end
end
%% POSTPROCESSING ERF interactions across subjects
if do_postproc_univar_interactions_across
    if 0
        isCond = load([proj_home '/misc/isConditioned.txt']);isCond = isCond(:,2);
        isCondSuffix = '_isCond';
    else
        isCond = ones(length(subjects),1);
        isCondSuffix = '';
    end
    for analysis = analyses
        analysis = analysis{1};
                
        % Contrasts
        contrasts = {'faceXodd','csXoddXses'};
        for contrast = contrasts
            contrast=contrast{1};
            ss = 1;
            %% concatenate data across subjects within a fieldtrip structure
            for s = 1:length(subjects)
                if isCond(s) > 0
                    clear data
                    file = [output_path 'erf/' subjects(s).name '/' subjects(s).name '_' analysis '_erf_univariate.mat'];
                    data = load(file, contrast);
                    if ss == 1
                        all_erf = data.(contrast).erf;
                        all_p = data.(contrast).p;
                    else
                        all_erf.trials{ss} = data.(contrast).erf.trial{1};
                        all_p.trials{ss} = data.(contrast).p.trial{1};
                    end
                    ss = ss + 1;
                end
            end
            
            %% plot ERF
            cfg             = [];
            cfg.toi         = -.030:.030:.250;
            cfg.tlim_timeXtrial = [-0.2 0.300];
            cfg.zlim_mag    = [-2 2]*1e-13;
            cfg.zlim_grad   = [0 3]*1e-12;
            cfg.save        = true;
            cfg.figure_name = [output_path 'erf/across_subjects/across_subjects_' analysis '_erf_' contrast 'ERF' isCondSuffix];
            plot_all(all_erf,cfg);
            
            %% plot p values
            cfg             = [];
            cfg.toi         = -.030:.03:.250;
            cfg.tlim_timeXtrial = [-0.2 0.300];
            cfg.zlim_mag    = [0 6];
            cfg.zlim_grad   = [0 6];
            cfg.save        = true;
            cfg.figure_name = [output_path 'erf/across_subjects/across_subjects_' analysis '_erf_' contrast 'P_isCond'];
            plot_all(all_p,cfg);
        end
        close all;
    end
end



%% Sand box 
if do_sandbox
    % test for the critical contrast: i.e. train in pre conditioning to
    % discriminate emotional (odd) versus neutral (standard) faces and
    % generalize to post conditioning to test whether conditioned faces (face
    % 1) is better predicted than non-conditioned face (face 2);
    
    
    for s = length(subjects):-1:1
        % load data structure
        file = [output_path 'erf/' subjects(s).name '/' subjects(s).name '_' analysis '_erf'];
        load([file '.mat'],'data');
        % trial information
        face = data.trialinfo(:,4)+1;
        odd = data.trialinfo(:,5)+1;
        prepost = data.trialinfo(:,7);
        % remove trials exluded from analysis
        sel = prepost==3;
        face(sel) = [];
        odd(sel) = [];
        prepost(sel) = [];
        % divide pre and post trials
        face_pre = face(prepost==1);
        face_post = face(prepost==2);
        odd_pre = odd(prepost==1);
        odd_post = odd(prepost==2);
        prepost_pre = prepost(prepost==1);
        prepost_post = prepost(prepost==2);
        
        % load decoding output
        results=load([file '_' contrast '_results.mat'],'probas','probasg', 'y','yg', 'dims','features');
        % problem of non exactly identical timing across subjects.
        
        auc_pre(s,:) = colAUC(squeeze(results.probas(:,:,:,1,1)), results.y);
        auc_post(s,:) = colAUC(squeeze(results.probasg(:,:,:,1,1)), -results.yg);
        
        % face 1
        for f = 1:2
            auc_pre_face(s,:,mod(subjects(s).scenario+f,2)+1) = colAUC(squeeze(results.probas(:,face_pre==f,:,1,1)), results.y(face_pre==f));
            auc_post_face(s,:,mod(subjects(s).scenario+f,2)+1) = colAUC(squeeze(results.probasg(:,face_post==f,:,1,1)), -results.yg(face_post==f));
        end
    end
    %% retrieve time
    time = data.time{1}(results.dims);
    %% plot
    figure();set(gcf,'color','w');
    subplot(3,1,1);hold on;
    plot_eb(time,auc_pre_face(:,:,1),[0 0 1]);
    plot_eb(time,auc_pre_face(:,:,2),[1 0 0]);
    title('Pre')
    axis tight;axis([xlim .45 .7]);box off;hold on;plot(xlim,[.5 .5],'--k');
    legend('Face 1','.','Face 2');
    title('Pre');
    subplot(3,1,2); hold on;
    plot_eb(time,auc_post_face(:,:,1),[0 0 1]);
    plot_eb(time,auc_post_face(:,:,2),[1 0 0]);
    axis tight;axis([xlim .45 .7]);box off;hold on;plot(xlim,[.5 .5],'--k');
    legend('Face 1','.','Face 2');
    title('Post');
    subplot(3,1,3);hold on;
    plot_eb(time,auc_post_face(:,:,2)-auc_post_face(:,:,1),[0 0 0]);
    axis tight;box off;hold on;plot(xlim,[0 0],'--k');
    p = ranksum_fast(auc_post_face(:,:,2),auc_post_face(:,:,1));
    alpha=.05;
    scatter(time(p<alpha),zeros(sum(p<alpha),1),'filled');

%{
change file names

for subject = subjects
    files = dir([output_path 'erf/' subject.name '/' subject.name '_*condition*']);
    for f =1:length(files)
        filename = files(f).name;
        ii = strfind(filename,'condition');
        movefile(...
            [output_path 'erf/' subject.name '/' filename],...
            [output_path 'erf/' subject.name '/' filename(1:(ii-1)) 'prepost' filename((ii+length('condition')):end)])
    end
end
%}
end