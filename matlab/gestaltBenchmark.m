function diffs = gestaltBenchmark(ge,N,nRun,nSamples,maxStep,name,hyperparams)
    defaults.rateMethod     = 'componentwise_goal';
    defaults.learningRate   = 0.001;
    defaults.multistep      = false;
    
    defaults.batchSize      = 10;
    defaults.obsVar         = 0.01;
    defaults.sparsity       = 0.2;
    
    if isempty(hyperparams)
        hyperparams = {{}};
    end
    nParams = size(hyperparams,2);
    parametrisations = cell(1,nParams);
    for hp=1:nParams
        fprintf('Parametrisation %d/%d ',nParams,hp);
        actparam = defaults;
        actparam = updateStruct(actparam,hyperparams{hp});
        parametrisations{hp} = actparam;
        save(sprintf('%s_params.mat',name),'parametrisations');
        
        diffs = zeros(nRun,maxStep+1);
        fprintf('Run %d/',nRun);
        for r=1:nRun
            printCounter(r);
            ge = gestaltGenerate(ge,N,'verbose',false,'batchSize',actparam.batchSize,'obsVar',actparam.obsVar,'sparsity',actparam.sparsity);
            diffs(r,:) = gestaltIEM(ge,ge.X,nSamples,maxStep,'shuffle','plot',0,'verbose',1,'rateMethod',actparam.rateMethod,'learningRate',actparam.learningRate,'multistep',actparam.multistep);
            save(sprintf('%s_diffs_param%d.mat',name,hp),'diffs');
            copyfile('iter.mat',sprintf('%s_iter_param%d_run%d.mat',name,hp,r));
        end
        fprintf('\n');
        h=plotConvergence(ge,diffs);
        saveas(h,sprintf('%s_convergence_param%d.fig',name,hp),'fig');
    end
end

function us = updateStruct(structure,cellArray)
    names = fieldnames(structure);
    us = structure;
    for i=1:size(names,1)        
        newValue = nextValue(cellArray,names(i));
        if ~isempty(newValue)
            us.(char(names(i))) = newValue;
        end
    end
end

function val = nextValue(cellArray,valName)
    val = '';
    for i=1:size(cellArray,2)
        if strcmp(cellArray{i},valName)
            val = cellArray{i+1};
            break;
        end
    end
end

    
    