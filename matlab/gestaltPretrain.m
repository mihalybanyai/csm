function [cc,winc,gbiasinc,vbiasinc] = gestaltPretrain(ge,steps,randseed,varargin)
    % learn RBM weights between v and g as Gaussian units with CD1 
    
    parser = inputParser;
    addParamValue(parser,'alpha',0.01,@isnumeric);
    addParamValue(parser,'gstep',0,@isnumeric);
    addParamValue(parser,'cdstep',1,@isnumeric);
    addParamValue(parser,'initVar',0.1,@isnumeric);
    addParamValue(parser,'gbias',true,@islogical);
    addParamValue(parser,'vbias',true,@islogical);
    parse(parser,varargin{:});
    alpha = parser.Results.alpha;    
    gstep = parser.Results.gstep;    
    cdstep = parser.Results.cdstep;    
    initVar = parser.Results.initVar; 
    gbias = parser.Results.gbias; 
    vbias = parser.Results.vbias; 
    
    if strcmp(randseed,'last')
        load lastrandseed;
    end
    s = RandStream('mt19937ar','Seed',randseed);
    RandStream.setGlobalStream(s);
    randseed = s.Seed;
    save('lastrandseed.mat','randseed');
    
    N = ge.N;
    X = ge.X;
    % transform out batches
    if ndims(X) == 3
        X = reshape(X,size(X,1)*size(X,2),size(X,3));
        N = ge.N * ge.B;
    end
        
    % initialise W
    g_bias = randn(ge.k,1) * initVar;
    v_bias = randn(ge.Dv,1) * initVar;
    W = randn(ge.Dv,ge.k) * initVar;
    pA = pinv(ge.A);
%     data_corr = zeros(ge.Dv,ge.k);
%     fantasy_corr = zeros(ge.Dv,ge.k);
%     data_hiddenact = zeros(1,ge.k);
%     fantasy_hiddenact = zeros(1,ge.k);
%     samples = cell(1,steps);
    winc = zeros(ge.Dv * ge.k,steps);
    gbiasinc = zeros(ge.k,steps);
    vbiasinc = zeros(ge.Dv,steps);
    
    % transform each line of X into a V by the pseudoinverse of A
    V_data = pA * X'; % TODO check whether we have to transpose

    for s = 1:steps
        V = V_data;
        % take one sample for each v from fake-G
        G = gibbsG(V,W,gstep,gbias,g_bias);
        % record G activity
        data_gact = sum(G,2);
        % record V activity
        data_vact = sum(V,2);
        % record positive phase correlations        
        data_corr = correlate(V,G);
        
        for cds=1:cdstep
            % update V 
            if vbias
                V_bias_input = repmat(v_bias,1,N);
            else
                V_bias_input = 0;
            end
            V = W * G + V_bias_input + randn(ge.Dv,N);
            % update G
            G = gibbsG(V,W,gstep,gbias,g_bias);
        end
        % record negative phase correlations
        fantasy_corr = correlate(V,G);
        % record G activity
        fantasy_gact = sum(G,2);
        % record V activity
        fantasy_vact = sum(V,2);
        
        % update W      
        W = W + alpha * (data_corr - fantasy_corr);
        winc(:,s) = W(:)';
        % update bias
        if gbias
            g_bias = g_bias + alpha * (data_gact - fantasy_gact) / N; 
            gbiasinc(:,s) = g_bias;
        end
        if vbias
            v_bias = v_bias + alpha * (data_vact - fantasy_vact) / N; 
            vbiasinc(:,s) = v_bias;
        end
        
    end
    
    % construct covariance components from W
    close all;
    cc = cell(1,ge.k);
    for k = 1:ge.k
        actc = zeros(ge.Dv);
        for i = 1:ge.Dv
            for j = 1:ge.Dv
                actc(i,j) = W(i,k) * W(j,k);
            end
        end
        cc{k} = actc;
        figure;
        viewImage(cc{k},'usemax',true);
    end        
end

function G = gibbsG(V,W,gstep,gbias,g_bias)
    k = size(W,2);
    N = size(V,2);
    if gbias
        G_bias_input = repmat(g_bias,1,N);
    else
        G_bias_input = 0;
    end
    G_mean = W' * V + G_bias_input;
    G = G_mean + randn(k,N);
    % updating all G-s alternatingly with negative weight between each
    % other
    for i=1:gstep
        for j = 1:k
            restG = G;
            restG(j,:) = [];
            G(j,:) = G_mean(j,:) - sum(restG,1) + randn(1,N);
        end
    end
end

function corr = correlate(A,B) 
    N = size(A,2);
    % standardise
    A = A ./ repmat(std(A,0,2),1,N);
    B = B ./ repmat(std(B,0,2),1,N);
    % covariance
    corr = A * B';
    % normalise
    corr = corr / N;
end