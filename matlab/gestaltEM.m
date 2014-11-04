function cholesky = gestaltEM(ge,X,emBatchSize,maxStep,nSamples,randseed,varargin)        
    parser = inputParser;
    addParamValue(parser,'learningRate',1,@isnumeric);    
    addParamValue(parser,'plot',0,@isnumeric);
    addParamValue(parser,'precision',false,@islogical);      
    addParamValue(parser,'verbose',2,@isnumeric);
    addParamValue(parser,'initCond','empty');
    addParamValue(parser,'priorG','gamma');
    addParamValue(parser,'syntheticData',true,@islogical);
    parse(parser,varargin{:});        
    params = parser.Results;      
    
    if params.plot>1
        % redefine plot to make figures more dense
        subplot = @(m,n,p) subtightplot (m, n, p, [0.025 0.001], [0 0.025], [0 0.01]);
        clf;
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%            
    % SET RANDOM SEED          
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    if strcmp(randseed,'last')
        load lastrandseed;
    end
    s = RandStream('mt19937ar','Seed',randseed);
    RandStream.setGlobalStream(s);
    randseed = s.Seed;
    save('lastrandseed.mat','randseed');

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%            
    % CREATE INITAL PARAMETER MATRICES AND MODEL STRUCTURE     
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    if strcmp(params.initCond,'random') 
        ccInit = randomCovariances(ge.k,ge.Dv,'precision',params.precision);        
    elseif strcmp(params.initCond,'shifted') 
        ccInit = gestaltCovariances(ge.k,ge.A',floor(sqrt(ge.Dx)/4));  
    elseif strcmp(params.initCond,'empty') 
        ccInit = cell(1,ge.k);
        for kk = 1:ge.k
            ccInit{kk} = 0.001 * eye(ge.Dv);
        end
    elseif strcmp(params.initCond,'pretrain')
        pre_seed = randi(intmax);
        data = reshape(X,size(X,1)*size(X,2),size(X,3));
        ge.X = repmat(data,floor(1000/size(data,1)),1);
        ccInit = gestaltPretrain(ge,1000,pre_seed,'plot',false);
        for kk = 1:ge.k
            ccInit{kk} = 10 * ccInit{kk};
            ccInit{kk} = max(ccInit{kk}(:)) * eye(ge.Dv);
        end
    end
    
    cholesky = cellchol(ccInit);                  
    cc_old = extractComponents(ge,params.precision);    
    ge = replaceComponents(ge,ccInit,params.precision);

    sdim = ge.k+(ge.Dv*ge.B);
    % correct learning rate for data set size
    params.learningRate = params.learningRate * (10 / emBatchSize);
    ge.N = size(ge.X,1);  
    if ndims(X) == 2
        if ge.B > 1
            throw(MException('Gestalt:EM:WrongBatchSize','The data is not organised to batches while the model is specified for batches of observarions of size %d',ge.B));
        end
        X = reshape(X,size(X,1),1,ge.Dv);
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%            
    % INITIALISE ARRAYS FOR SAVING VALUES   
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                            
    
    % the best permutation for comparing estimated components to truth    
    state_sequence = cell(1,maxStep+1);   
    true_c = componentSum(ones(ge.k,1),cc_old);
    act_c = componentSum(ones(ge.k,1),ccInit);
    if params.syntheticData
        state.difference_to_truth = covcompRootMeanSquare(act_c,true_c,1);        
        if params.detailedDiff
            state.detailed_difference = covcompRootMeanSquare(ccInit,cc_old,[],'verbose',true);
        end
    end
    state.matrix_norms = {};
    for i=1:ge.k
        state.matrix_norms{i} = norm(ccInit{i});
    end
    state.relative_difference = 0;        
    state.estimated_components = ccInit;
    state.samples = [];
    state_sequence{1} = state;                  
            
    cc_next = cell(1,ge.k);
    
    for step=1:maxStep
        fprintf('EM step %d/%d',maxStep,step)
        
        cc_prev = extractComponents(ge,params.precision);
             
        % choose a batch from tha big dataset randomly
        ge.X = X(chooseKfromN(emBatchSize,size(X,1)),:,:);        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%            
        % E - step            
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        samples = zeros(emBatchSize,nSamples,sdim);    
        skipped = 0;
        for n=1:emBatchSize
            
             if params.verbose == 2
                 fprintf('\nDatapoint %d/%d ',emBatchSize,n);            
             end         

            % Gibbs sampling
            initG = (1/ge.k) * ones(ge.k,1);
            try
                [samples(n,:,:),~] = gestaltGibbs(ge,n,nSamples,'verbose',params.verbose-1,'precision',params.precision,'initG',initG,'priorG',params.priorG,'contrast',ge.contrast);            
            catch
                % if couldn't find a valid g-sample in 10 steps, skip
                skipped = skipped + 1;
                continue;
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%            
        % M - step            
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % gradient of the parameters of the complete-data log-likelihood            
        grad = gestaltParamGrad(ge,samples,cholesky,'precision',params.precision,'verbose',params.verbose);                        

        % update cholesky components
        for j=1:ge.k
            cholesky{j} = cholesky{j} + params.learningRate .* grad{j};
            cc_next{j} = cholesky{j}' * cholesky{j};                                             
        end

        ge = replaceComponents(ge,cc_next,params.precision);      

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%            
        % PRINT AND SAVE DATA            
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%            
                
        state.relative_difference = covcompRootMeanSquare(cc_next,cc_prev,1:ge.k);
        % TEST
        %state.relative_difference = 1;
        act_c = componentSum(ones(ge.k,1),cc_next);
        if params.syntheticData
            state.difference_to_truth = covcompRootMeanSquare(act_c,true_c,1);
        end
        state.estimated_components = extractComponents(ge,params.precision);
        state.samples = samples;
        state.matrix_norms = {};
        for i=1:ge.k
            state.matrix_norms{i} = norm(cc_next{i});
        end
        state_sequence{step+1} = state;                
        
        S{step} = samples;
        save('iter.mat','state_sequence');
        if params.verbose == 2
            fprintf(' diff %.2e skipped %d\n',state.relative_difference,skipped);
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%            
        % TEST FOR CONVERGENCE   
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        if state.relative_difference < 1e-6
            if params.verbose>1
                fprintf('Convergence achieved in %d steps.\n',step);
            end
            break;
        end
        
        %whos
    end        

    if params.plot>0
        if ge.k > 5
            plotsize = ceil(sqrt(ge.k));
            for act_k=1:ge.k
                subplot(plotsize,plotsize,act_k);
                viewImage(cc_next{act_k});
            end
        else
            ge = replaceComponents(ge,cc_old,params.precision);
            plotCovariances(ge,ge.N,params.precision,[]);
        end
    end    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%            
% FUNCTIONS FOR CALCULATIONS, PLOTTING AND DATA ACCESS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function ge = replaceComponents(ge,comps,precision)
    if ~precision       
        ge.cc = comps;
    else      
        ge.pc = comps;
    end
end

function comps = extractComponents(ge,precision)
    if ~precision
        comps = ge.cc;        
    else
        comps = ge.pc;        
    end
end