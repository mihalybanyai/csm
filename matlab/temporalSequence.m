function temporalSequence(ge,quantity,remove,trials,shift,plot_bars)
    randstim = randn(ge.B,ge.Dx);    
    
    ge.obsVar = 1;
    sAA = (1/ge.obsVar) * ge.AA;
    
    ps = zeros(sqrt(ge.Dx));
    ps(2:5,3) = 1;
    ps = ps(:)';
    
    fullStim = zeros(sqrt(ge.Dv));
    fullStim(2:7,3) = 1;
    fullStim = fullStim(:)';
    
    confound = zeros(sqrt(ge.Dv));
    % set confound
    confound(2:5,4) = 1;
    confound = confound(:)';
    
    gest_idx = logical(fullStim - ps);
    stim_idx = logical(ps);
    conf_idx = logical(confound);
    other_idx = logical(ones(1,ge.Dv) - fullStim - confound);
    idxs = {stim_idx,gest_idx,conf_idx,other_idx};
    groupnum = 4;
    
    covidxs = cell(1,groupnum);
    for i=1:groupnum
        act = zeros(ge.Dv);
        for j=1:ge.Dv
            for k=j+1:ge.Dv
                if idxs{i}(j) == 1 && idxs{i}(k) ==1
                    act(j,k) = 1;
                end
            end
        end
        covidxs{i} = logical(act);
    end
    
    sequence_length = 6;
    v_all = zeros(trials,groupnum,sequence_length);
    g_all = zeros(trials,ge.k,sequence_length);
    
    for t=1:trials
        stim = gestaltStimulus(ge.Dx,ge.B,true,true,true);
        
        v_means = []; % sim will be 4xT (stimulus,gestalt,confound,other)
        v_stds = [];
        g_seq = [];

        % T0
        % calculate baseline mean and variance of g from the prior
        % calculate mean and variance of v if there is no signal in the input
        if ge.nullComponent
            g_act = zeros(ge.k,1);
            for d = 1:ge.k            
                if ge.nullComponent && d == ge.k
                    g_act(d,1) = gamrnd(ge.null_shape,ge.null_scale);
                else
                    g_act(d,1) = gamrnd(ge.g_shape,ge.g_scale);
                end
            end
            cv = componentSum(g_act,ge.cc);
            v_samp_batch = mvnrnd(zeros(ge.B,ge.Dv),cv);
            v_act = sortV(v_samp_batch,idxs,covidxs,quantity,g_act,ge.cc,sAA);
        else
%             g_act = (1/ge.k) * ones(ge.k,1);
%             % TEST
%             g_act = [0.1;0.9];
%             v_act = zeros(4,1);
        end        

        g_seq = [g_seq g_act];
        v_means = [v_means v_act];

        % T1
        % set the input to a partial activation of a gestalt plus unexplained
        % confounding variance
        % calculate mean and variance of v conditioned on the input and g
        g_seq = [g_seq g_act];
        ge.X(1,:,:) = stim;
        v_samp_batch = gestaltPostVRnd(ge,1,g_act,1,false);
        v_act = sortV(v_samp_batch,idxs,covidxs,quantity,g_act,ge.cc,sAA);
        v_means = [v_means v_act];        

        % T2
        % calculate mean and variance of g conditioned on v
        logpdf = @(g) gestaltLogPostG(g,v_samp_batch,ge,'dirichlet',false); 
        g_part = g_act(1:ge.k-1,1);
        for i=1:5
            [g_part,~] = sliceSample(g_part,logpdf,0.05,'limits',[0,1]);
        end
        g_act = [g_part; 1-sum(g_part)];
        g_seq = [g_seq g_act];
        v_means = [v_means v_act];

        % T3
        % set the input signal back to nothing
        % update v
        g_seq = [g_seq g_act];
        if remove
            ge.X(1,:,:) = randstim;
        else
            ge.X(1,:,:) = stim;
        end
        v_samp_batch = gestaltPostVRnd(ge,1,g_act,1,false);
        v_act = sortV(v_samp_batch,idxs,covidxs,quantity,g_act,ge.cc,sAA);
        v_means = [v_means v_act];   

        % T4
        % update g
        logpdf = @(g) gestaltLogPostG(g,v_samp_batch,ge,'dirichlet',false); 
        g_part = g_act(1:ge.k-1,1);
        for i=1:1
            [g_part,~] = sliceSample(g_part,logpdf,0.05,'limits',[0,1]);
        end
        g_act = [g_part; 1-sum(g_part)];
        g_seq = [g_seq g_act];
        v_means = [v_means v_act];
        
        % T5
        % update v
        g_seq = [g_seq g_act];
        if remove
            ge.X(1,:,:) = randstim;
        else
            ge.X(1,:,:) = stim;
        end
        v_samp_batch = gestaltPostVRnd(ge,1,g_act,1,false);
        v_act = sortV(v_samp_batch,idxs,covidxs,quantity,g_act,ge.cc,sAA);
        v_means = [v_means v_act];   
        
        % store values
        v_all(t,:,:) = v_means;
        g_all(t,:,:) = g_seq;
    end
    
    v_plot = squeeze(mean(v_all,1));
    g_plot = squeeze(mean(g_all,1));
    
    if shift
        v_plot = v_plot + repmat((0:groupnum-1)*0.001,sequence_length,1)';
    end
    
    if plot_bars
        v_plot = [v_plot(:,1) v_plot(:,2:2:sequence_length)];
        bar(v_plot');
        hold on;
        gx = [0.5 1.5 2.45 2.55 3.45 3.55 4.5]; % only valid for sequence_length = 6
        plot(gx',[g_plot(1,1) g_plot(1,:)]','LineWidth',3)
    else
        ph = plot([v_plot;g_plot(1,:)]','LineWidth',1.5);
        set(ph(5),'linewidth',3);
    end
    hold on;
    lh=legend('stimulated V1','gestalt V1','confound V1','other V1','higher');
    set(lh,'Location','NorthEastOutside');
    
    % plot stimulus onset
    if remove
        areaxlim = [2 3];
    else
        areaxlim = [2 sequence_length];
    end
    if plot_bars
        areaxlim(1) = areaxlim(1) - 0.5;
        areaxlim(2) = areaxlim(2) - 1.5;
    end
        
    yl = ylim;
    H = area([areaxlim fliplr(areaxlim)],[yl(2) yl(2) yl(1) yl(1)],'LineStyle','none');
    h=get(H,'children');
    set(h,'FaceAlpha',0.05,'FaceColor',[0 0 1]);
    hold off;
end


function mr = meanCorr(X)
    dim = size(X,1);
    co = corrcoef(X);
    ut = triu(co) - diag(diag(co));
    mr = mean(ut(:)) * (dim^2 / (dim^2 / 2 + dim / 2));
end

function v_act = sortV(v_samp_batch,idxs,covidxs,quantity,g_act,cc,sAA)
    v_samp = mean(v_samp_batch,1);
    groupnum = size(idxs,2);
    
    if strcmp(quantity,'mean')
        v_act = [];
        for i = 1:groupnum
            mc = mean(v_samp(idxs{i}));
            v_act = [v_act; mc];
        end
    elseif strcmp(quantity,'noisecorr')        
        cv = componentSum(g_act,cc);
        actcorr = corrcov(inv(sAA + inv(cv)));
        
        v_act = [];
        for i = 1:groupnum
            selected_corr = actcorr(covidxs{i});
            v_act = [v_act; mean(selected_corr(:))];
        end
    elseif strcmp(quantity,'allcorr')
        v_act = [];
        for i = 1:groupnum
            mc = meanCorr(v_samp_batch(:,idxs{i}));
            v_act = [v_act; mc];
        end
    end
end