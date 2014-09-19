function testGConvergence(trials,steps)
    % create models with different numbers of components
    nModels = 3;
    B = 10;
    Dv = 64;
    allmodels = cell(1,2*nModels-1);
    ge1 = gestaltCreate('temp','k',1,'Dx',Dv,'N',1,'B',B);
    allmodels{1} = ge1;
    ge_ovl = {};
    ge_nonovl = {};
    legends = cell(1,2*nModels-1);
    legends{1} = 'one';
    for k = 2 : nModels
        ge_ovl{k-1} = gestaltCreate('temp','k',k,'Dx',Dv,'N',1,'B',B,'overlapping',true);
        allmodels{k} = ge_ovl{k-1};
        ge_nonovl{k-1} = gestaltCreate('temp','k',k,'Dx',Dv,'N',1,'B',B,'overlapping',false);
        allmodels{nModels+k-1} = ge_nonovl{k-1};
        legends{k} = sprintf('overlap %d',k);
        legends{nModels - 1 + k} = sprintf('non-ovl %d',k);
    end            
    
    g_series = zeros(trials,2*nModels-1,steps);
        
    for m=1:2*nModels-1
        printCounter(m,'maxVal',2*nModels-1,'stringVal','Model');
        % create stimulus template
        stim_temp = zeros(sqrt(Dv),sqrt(Dv)); 
        if m > 1 && m < nModels
           stim_temp(2:7,3) = 1;
           stim_temp(4:7,4) = 1;
           stim_temp(4:5,5) = 1;               
        else
           stim_temp(2:5,2) = 1;
           stim_temp(2:3,4:6) = 1;
        end               
        stim_temp = logical(stim_temp(:));
        for t=1:trials
            % create actual stimulus
            act_stim = randn(B,Dv);
            act_stim(:,stim_temp) = act_stim(:,stim_temp) + 2;
            % set stimulus to model
            allmodels{m}.X(1,:,:) = act_stim;        
            s = gestaltGibbs(allmodels{m},1,steps);
            % extract g samples
            g_series(t,m,:) = s(:,1);
        end
    end    
    
    to_plot = squeeze(mean(g_series,1))';
    
    % plot results
    plot(to_plot);
    legend(legends);
    
end