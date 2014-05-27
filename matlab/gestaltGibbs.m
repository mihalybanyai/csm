function [s,rr] = gestaltGibbs(ge,xind,nSamp,varargin)
    parser = inputParser;
    addParamValue(parser,'verbose',0,@isnumeric);
    addParamValue(parser,'stepsize',0.05,@isnumeric);
    addParamValue(parser,'burnin',0,@isnumeric);
    addParamValue(parser,'thin',1,@isnumeric);
    addParamValue(parser,'plot',0,@isnumeric);
    addParamValue(parser,'sampleRetry',10,@isnumeric);
    addParamValue(parser,'precision',false,@islogical);
    addParamValue(parser,'approximatePostCov',false,@islogical);
    parse(parser,varargin{:});
    verb = parser.Results.verbose;    
    pl = parser.Results.plot;    
    retry = parser.Results.sampleRetry;    
    precision = parser.Results.precision;
    burn = parser.Results.burnin;
    thin = parser.Results.thin;
    N = nSamp*thin + burn;
    stepsize = parser.Results.stepsize;
    approx = parser.Results.approximatePostCov;    
    
    s = zeros(N,ge.k + ge.B*ge.Dv);
    rr = 0;
    %g = 0.5 * ones(ge.k,1);
    valid = false;
    tries = 0;
    %fprintf(' looking for a valid g');
    while ~valid
        g = symmetricDirichlet(0.2,ge.k,1)';
        valid = checkG(g,ge,precision);
        tries = tries + 1;
        % if we cannot find a valid g, return an error code
        if tries > retry
            rr = -1;
            return;
        end
    end
    %fprintf(repmat('\b',1,22));
    V = zeros(ge.B,ge.Dv); % unused if we sample the conditional over v first
        
    if verb==1
        fprintf('Sample %d/',N);
    end
    for i=1:N
        if verb==1
            printCounter(i);
        end
        
        % generate a direct sample from the conditional posterior over v        
        V = gestaltPostVRnd(ge,xind,g,precision,approx);
        
        if pl > 0
            clf;
            gestaltPlotCondPostG(ge,V,precision);
            hold on;
            plot(ge.G(xind,1),0,'go');
            pause
        end
        
        % slice sampling for g
        logpdf = @(g) gestaltLogPostG(g,V,ge,precision); 
        
        valid = false;
        tries = 0;
        while ~valid
            if tries > retry                
                rr = -i -1;
                return;
            end
            [g_part,rr_act] = sliceSample(g(1:ge.k-1,1),logpdf,stepsize,'plot',pl>1);
            g = [g_part; 1-sum(g_part)];
            valid = checkG(g,ge,precision);
            tries = tries + 1;
        end
        rr = rr + rr_act;

        % uncomment this and comment out the similar line in the beginning if
        % you want to reverse the order of sampling from the conditionals
        % if ~precision
        %     V = gestaltPostVRnd(ge,xind,g);
        % else
        %     V = gestaltPostVRndPrec(ge,xind,g);
        % end
        
        % store the combined sample
        vlong = reshape(V,1,ge.B*ge.Dv);
        s(i,:) = [g' vlong];
    end
%     if verb==1
%         fprintf('\n');
%     end
    
    % calculate the rejection rate
    rr = rr / (rr + N);
    
    % discard burn-in stage
    if burn > 0
        s = s(burn+1:N,:);
    end
    if thin > 1
        indices = 1:thin:nSamp*thin;
        s = s(indices,:);
    end
end

function good = checkG(g,ge,precision)
    good = true;
    if ~precision
        CvP = componentSum(g,ge.cc);
    else
        CvP = componentSum(g,ge.pc);
    end
    if rcond(CvP) < 1e-15
        good = false;
        return;
    end
    if ~precision
        postP = (1/ge.obsVar) * ge.AA + inv(CvP);                
    else
        postP = (1/ge.obsVar) * ge.AA + CvP;                
    end
    if rcond(postP) < 1e-15
        good = false;
        return;
    end
    
    %postC = inv(postP);
    [~,err] = cholcov(postP);
    %if det(CvP) > 0 && det(postC) > 0 && err == 0                
    if err ~= 0                
        good = false;                
    end
end