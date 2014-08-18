function [s,rr,zsamp] = gestaltGibbs(ge,xind,nSamp,varargin)
    parser = inputParser;
    addParamValue(parser,'verbose',0,@isnumeric);
    addParamValue(parser,'stepsize',0.05,@isnumeric);
    addParamValue(parser,'burnin',0,@isnumeric);
    addParamValue(parser,'thin',1,@isnumeric);
    addParamValue(parser,'plot',0,@isnumeric);
    addParamValue(parser,'sampleRetry',10,@isnumeric);
    addParamValue(parser,'precision',false,@islogical);
    addParamValue(parser,'contrast',false,@islogical);
    addParamValue(parser,'initG',[]);
    addParamValue(parser,'priorG','dirichlet');
    parse(parser,varargin{:});
    params = parser.Results;

    N = nSamp*params.thin + params.burnin;        
    
    s = zeros(N,ge.k + ge.B*ge.Dv);
    zsamp = zeros(N,1);
    rr = 0;
    %g = (1/k) * ones(ge.k,1);
    valid = false;
    tries = 0;
    %fprintf(' looking for a valid g');
    if isempty(params.initG)
        while ~valid
            g = symmetricDirichlet(0.2,ge.k,1)';
            valid = checkG(g,ge,params.precision);
            tries = tries + 1;
            % if we cannot find a valid g, return an error code
            if tries > params.sampleRetry
                rr = -1;
                return;
            end
        end
    else
        g = params.initG;
    end
    %fprintf(repmat('\b',1,22));
    V = zeros(ge.B,ge.Dv); % unused if we sample the conditional over v first
    z = 1; % remains unchanged if we do not use a contrast variable
    % TODO we might sample z from its prior
        
    if params.verbose==1
        fprintf('Sample %d/',N);
    end
    for i=1:N
        if params.verbose==1
            printCounter(i);
        end
        
        % generate a direct sample from the conditional posterior over v        
        V = gestaltPostVRnd(ge,xind,g,z,params.precision);
        
        if params.plot > 0
            clf;
            gestaltPlotCondPostG(ge,V,params.precision);
            hold on;
            plot(ge.G(xind,1),0,'go');
            pause
        end
        
        % slice sampling for g
        logpdf = @(g) gestaltLogPostG(g,V,ge,params.priorG,params.precision); 
        
        valid = false;
        tries = 0;
        while ~valid
            if tries > params.sampleRetry                
                rr = -i -1;
                return;
            end
            if strcmp(params.priorG,'dirichlet')
                [g_part,rr_act] = sliceSample(g(1:ge.k-1,1),logpdf,params.stepsize,'plot',params.plot>1,'limits',[0,1]);
                g_temp = [g_part; 1-sum(g_part)];
            else
                [g_temp,rr_act] = sliceSample(g,logpdf,params.stepsize,'plot',params.plot>1);
            end
            tries = tries + 1;
            if rr_act == -1
                %fprintf('Sample %d omitted due to too many retries in slice sampling\n',i);
                continue
            end            
            valid = checkG(g,ge,params.precision);            
            if valid
                g = g_temp;
            end
        end
        rr = rr + rr_act;
        
        % slice sampling for z
        if params.contrast            
            zlogpdf = @(z) gestaltLogPostZ(z,xind,V,ge); 
            valid = false;
            tries = 0;
            while ~valid
                if tries > params.sampleRetry                
                    rr = -i -1;
                    return;
                end
                [z,rr_act] = sliceSample(z,zlogpdf,params.stepsize,'plot',params.plot>1);
                tries = tries + 1;
                if rr_act ~= -1
                    valid = true;
                end          
            end
            rr = rr + rr_act;
        end
        
        % store the combined sample
        vlong = reshape(V,1,ge.B*ge.Dv);
        s(i,:) = [g' vlong];
        zsamp(i,1) = z;
    end
%     if params.verbose==1
%         fprintf('\n');
%     end
    
    % calculate the rejection rate
    rr = rr / (rr + N);
    
    % discard burn-in stage
    if params.burnin > 0
        s = s(params.burnin+1:N,:);
    end
    if params.thin > 1
        indices = 1:params.thin:nSamp*params.thin;
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