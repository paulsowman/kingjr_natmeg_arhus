function results = jr_classify_stats(file,varargin)
%  jr_classify_stats(file/results [,varargin])

if nargin == 1
    varargin = {};
end

for ii = 1:2:length(varargin), eval([varargin{ii} '= varargin{ii+1}']); end


%% Load data
if ischar(file), results = load(file);
else results = file; end

%% Parameters
%-- stats
if ~exist('mean_across','var'), mean_across = 'trials'; end
if ~exist('stats_across','var'), stats_across = 'trials'; end
%-- data type
if ~exist('datatype','var'),
    if isfield(results, 'probas'), datatype = 'probas';
    elseif isfield(results, 'distance'), datatype = 'distance';
    end
end
eval(['data = results.' datatype ';']);
eval(['datag= results.' datatype 'g;']);

g= ~isempty(results.yg);

n_splits    = size(data,1);
n_folds     = size(results.all_folds,2);
classes     = unique(results.y);
n_classes   = length(classes);
gclasses     = unique(results.yg);
n_gclasses   = length(gclasses);

%% mean prediction
switch mean_across
    case 'trials'
        %% mean and std probabilities
        for c1 = 1:n_classes
            %-- for training categories
            for c2 = 1:n_classes
                results.mp(1,c1,c2,:,:) = nanmean(nanmean(data(1,results.y==classes(c2),:,:,c1),1),2);
                results.sp(1,c1,c2,:,:) = nanstd(nanmean(data(1,results.y==classes(c2),:,:,c1),1),[],2);
            end
            %-- for generalization categories
            for c2 = 1:n_gclasses
                results.mpg(1,c1,c2,:,:) = nanmean(nanmean(nanmean(datag(:,results.yg==gclasses(c2),:,:,c1,:),1),6),2);
                results.spg(1,c1,c2,:,:) = nanstd(nanmean(nanmean(datag(:,results.yg==gclasses(c2),:,:,c1,:),1),6),[],2);
            end
        end
    case 'split'
        %% mean and std probabilities
        for s = n_splits:-1:1
            for c1 = 1:n_classes
                %-- for training categories
                for c2 = 1:n_classes
                    results.mp(s,c1,c2,:,:) = nanmean(data(s,results.y==classes(c2),:,:,c1),2);
                    results.sp(s,c1,c2,:,:) = nanstd(data(s,results.y==classes(c2),:,:,c1),[],2);
                end
                %-- for generalization categories
                for c2 = 1:n_gclasses
                    results.mpg(s,c1,c2,:,:) = nanmean(nanmean(datag(s,results.yg==gclasses(c2),:,:,c1,:),6),2);
                    results.spg(s,c1,c2,:,:) = nanstd(nanmean(datag(s,results.yg==gclasses(c2),:,:,c1,:),6),[],2);
                end
            end
        end
    case 'fold'
        %% mean probabilities for each fold
        for s = n_splits:-1:1
            for k = n_folds:-1:1
                test = find(results.all_folds(s,k,:)==0);
                for c1 = 1:n_classes
                    %-- for training categories
                    for c2 = 1:n_classes
                        results.mpk(s,k,c1,c2,:,:) = nanmean(data(s,intersect(find(results.y==classes(c2)), test),:,:,c1),2);
                        results.spk(s,k,c1,c2,:,:) = nanstd(data(s,intersect(find(results.y==classes(c2)), test),:,:,c1),[],2);
                    end
                    %-- for generalization categories
                    for c2 = 1:n_gclasses
                        results.mpgk(s,k,c1,c2,:,:) = nanmean(datag(s,results.yg==gclasses(c2),:,:,c1,k),2);
                        results.spgk(s,k,c1,c2,:,:) = nanstd(datag(s,results.yg==gclasses(c2),:,:,c1,k),[],2);
                    end
                end
            end
        end
end


%% each 2x2 comparison
cs          = nchoosek(1:n_classes,2);
results.cs = cs;
for c = size(cs,1):-1:1
    switch stats_across
        case 'trials'
            sel = results.y==classes(cs(c,1)) | results.y==classes(cs(c,2));
            x = sq(nanmean(data(:,sel,:,:,cs(c,1)),1));
            y = results.y(sel)==classes(cs(c,1));
            [results.p(1,:,:) h stats] = ranksum_fast(...
                x(y==true,:,:),...
                x(y==false,:,:));
            results.auc(1,c,:,:) = stats.AUC;
            results.R(1,c,:,:) = stats.R;
        case 'split'
            for s = n_splits:-1:1
                sel = results.y==classes(cs(c,1)) | results.y==classes(cs(c,2));
                x = sq(data(s,sel,:,:,cs(c,1)));
                y = results.y(sel)==classes(cs(c,1));
                [results.p(s,:,:) h stats] = ranksum_fast(...
                    x(y==true,:,:),...
                    x(y==false,:,:));
                results.auc(s,c,:,:) = stats.auc;
                results.R(s,c,:,:) = stats.R;
            end
        case 'fold'
            for s = n_splits:-1:1
                for k = n_folds:-1:1
                    sel = (results.y==classes(cs(c,1)) ...
                        | results.y==classes(cs(c,2))) & ...
                        results.all_folds(s,k,:)==0;
                    x = sq(data(s,sel & test,:,:,cs(c,1)));
                    y = results.y(sel & test)==classes(cs(c,1));
                    [results.p(1,:,:,k) h stats] = ranksum_fast(...
                        x(y==true,:,:),...
                        x(y==false,:,:));
                    results.auc(s,c,:,:,k) = stats.auc;
                    results.R(s,c,:,:,k) = stats.R;
                end
            end
    end
end