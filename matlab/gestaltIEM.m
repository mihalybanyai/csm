function ge = gestaltIEM(ge,X,nSamples,maxStep,lrate,precision,randseed,plot)
    
    if strcmp(randseed,'last')
        load lastrandseed;
    end
    s = RandStream('mt19937ar','Seed',randseed);
    RandStream.setGlobalStream(s);
    randseed = s.Seed;
    save('lastrandseed.mat','randseed');
            
    ccInit = randomCovariances(ge.k,ge.Dv,'precision',precision);
    
    X_old = ge.X;
    N_old = ge.N;
    
    if ~precision
        cc_old = ge.cc;
        ge.cc = ccInit;
    else
        cc_old = ge.pc;
        ge.pc = ccInit;
    end
    
    ge.X = X;
    ge.N = size(ge.X,1);
    sdim = ge.k+(ge.Dv*ge.B);
    % maximum change of a parameter over a cycle should not be more than:
    goaldiff = (2 / ge.N) * ones(ge.Dv);
    % empirical correction of the dimension dependence of the largest eigenvalue of the inverse covariance
    goaldiff = goaldiff / (ge.Dv * 0.025);
    
    cholesky = ccInit;
    for j=1:ge.k
        cholesky{j} = chol(cholesky{j});
    end    
    cholparnum = (ge.Dv^2 + ge.Dv) / 2;
    
    pCC{1} = ccInit;
    S = {};
    
    if plot
        subplot = @(m,n,p) subtightplot (m, n, p, [0.025 0.001], [0 0.025], [0 0.01]);
        clf;
    end
    
    cc_next = cell(1,ge.k);
    samples = zeros(ge.N,nSamples,sdim);
    for i=1:maxStep
        fprintf('IEM cycle %d datapoint %d/',i,ge.N);
        if plot
            nopause = false;
        end
        if ~precision
            cc_prev = ge.cc;
        else
            cc_prev = ge.pc;
        end
        
        skipped = 0;
        avgrate = 0;
        for n=1:ge.N
            printCounter(n);
            fprintf(' ');
            
            % E-step: Gibbs sampling
            [samples(n,:,:),rr] = gestaltGibbs(ge,n,nSamples,'verbose',1,'precision',precision);            
            if rr < 0                
                fprintf('\b');                
                skipped = skipped + 1;
                continue;
            end
            
            % M-step: gradient ascent            
            grad = gestaltParamGrad(ge,samples(n,:,:),cholesky,'precision',precision);                        
            
            % choose learning rate
            meanvals = zeros(1,j);
            for j=1:ge.k
                meanvals(1,j) = meanvals(1,j) + mean(mean(abs(grad{j}),2),1);
            end
            meanval = mean(meanvals,2);   
            
            oldchol = cholesky;
            for j=1:ge.k
                % choose learning rate
                %actrate = min(goaldiff ./ abs(grad{j}),lrate * ones(ge.Dv));
                %actrate = min(goaldiff / meanval,lrate * ones(ge.Dv));
                actrate = min(goaldiff / meanvals(1,j),lrate * ones(ge.Dv));
                avgrate = avgrate + sum(sum(actrate))/cholparnum;
                % update 
                cholesky{j} = cholesky{j} + actrate .* grad{j};
                cc_next{j} = cholesky{j}' * cholesky{j};                                
            end     
            
            if plot
                hor = 6;
                for j=1:ge.k
                    % cholesky
                    subplot(ge.k,hor,(j-1)*hor+1);
                    viewImage(cholesky{j},'magnif',false);
                    title(sprintf('chol %d at %d#%d',j,i,n));                    
                    % gradients
                    subplot(ge.k,hor,(j-1)*hor+3);
                    %compgrad = grad{j}/oldchol{j};
                    compgrad = grad{j};
                    learnrate = min(goaldiff(1,1)/meanvals(1,j),lrate);
                    viewImage(compgrad,'magnif',false);
                    gavg = mean(squeeze(samples(n,:,j)));
                    title(sprintf('grad sg%d=%.3f',j,gavg));
                    % delta
                    subplot(ge.k,hor,(j-1)*hor+4);
                    viewImage(compgrad*learnrate,'magnif',false);                    
                    title(sprintf('delta lr=%.3f',learnrate));
                    % next components
                    subplot(ge.k,hor,(j-1)*hor+5);
                    viewImage(cc_next{j},'magnif',false);
                    title(sprintf('comp %d at %d#%d',j,i,n));
                    % truth
                    subplot(ge.k,hor,(j-1)*hor+6);
                    viewImage(cc_old{j},'magnif',false);
                    title(sprintf('true comp %d',j));
                end
                % data cov                    
                subplot(ge.k,hor,2);
                viewImage(cov(squeeze(ge.X(n,:,:))),'magnif',false);
                title(sprintf('data cov, g1=%.3f',ge.G(n,1)));
                % sample cov                    
                subplot(ge.k,hor,hor+2);
                vsamp = reshape(samples(n,:,ge.k+1:sdim),nSamples*ge.B,ge.Dv);
                viewImage(cov(vsamp),'magnif',false);
                title('sample cov');
                pause(0.01);
                if ~nopause
                    ch = getkey('non-ascii');
                    if strcmp('f',ch)
                        nopause = true;
                    elseif strcmp('r',ch)
                        plot = false;
                    end
                end
            end
            
            % update parameters
            if ~precision
                ge.cc = cc_next;
            else
                ge.pc = cc_next;
            end
            
            for b=1:9+2*(floor(log10(nSamples))+1)
                fprintf('\b');
            end
        end
        
        diff = 0;
        for j=1:ge.k
            diff = diff + sum(sum((cc_next{j}-cc_prev{j})*(cc_next{j}-cc_prev{j})));           
        end
        diff = diff / (ge.k*ge.Dv^2);
        
        if ~precision
            pCC{i+1} = ge.cc;
        else
            pCC{i+1} = ge.pc;
        end
        
        S{i} = samples;
        save('iter.mat','pCC','S');
        fprintf(' avglr %.2e diff %.2e skipped %d\n',avgrate/(ge.N*ge.k),diff,skipped);
    end
        
    ge.X = X_old;
    dnum = ge.N;
    ge.N = N_old;
    
    if ~precision
        ge.pCC = ge.cc;        
        ge.cc = cc_old;
    else
        ge.pPC = ge.pc;        
        ge.pc = cc_old;
    end
    plotCovariances(ge,dnum,precision);
end
