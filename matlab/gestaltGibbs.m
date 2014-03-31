function [s,rr] = gestaltGibbs(ge,xind,nSamp,g_sampler,stepsize,varargin)
    parser = inputParser;
    addParamValue(parser,'verbose',0,@isnumeric);
    addParamValue(parser,'burnin',0,@isnumeric);
    addParamValue(parser,'plot',false,@islogical);
    parse(parser,varargin{:});
    verb = parser.Results.verbose;    
    plot = parser.Results.plot;    
    burn = parser.Results.burnin;
    N = nSamp + burn;
    
    s = zeros(N,ge.k + ge.Dv);
    rr = 0;
    g = 0.5 * ones(ge.k,1);
    v = zeros(ge.Dv,1); % unused if we sample the conditional over v first
    
    if strcmp(g_sampler,'hmc')
        bounds = [1:ge.k-1 repmat([0 1],ge.k-1,1)];
        grad = @(g) gestaltPostGGrad(g,v,ge);
    end
    
    if verb==1
        fprintf('Sample %d/',N);
    end
    for i=1:N
        if verb==1
            printCounter(i);
        end
        
        % generate a direct sample from the conditional posterior over v
        v = gestaltPostVRnd(ge,xind,g);
        
        if plot
            clf;
            gestaltPlotCondPostG(ge,v);
            hold on;
            pause
        end
        
        % Metropolis-Hastings scheme to sample from the conditional
        % posterior over g
        if strcmp(g_sampler,'hmc') || strcmp(g_sampler,'mh')
            accept = false;
            lp_act = gestaltLogPostG(g,v,ge);
            while ~accept
                if strcmp(g_sampler,'mh')
                    % propose from a unit Gaussian of dimension K-1
                    g_part = mvnrnd(g(1:ge.k-1,1)',stepsize*eye(ge.k-1))';
                else
                    % propose from Hamiltonian dynamics
                    p_init = mvnrnd(zeros(ge.k-1),0.01*eye(ge.k-1))';                
                    [p_end,g_part] = leapfrog(p_init,g(1:ge.k-1,1),grad,stepsize,100,bounds);
                    K_init = sum(p_init.^2) / 2;
                    K_end = sum(p_end.^2) / 2;
                end

                % the last element is determined by the rest
                g_next = [g_part; 1-sum(g_part)];
                a = rand();
                lp_next = gestaltLogPostG(g_next,v,ge);
                if strcmp(g_sampler,'mh')
                    limit = lp_next - lp_act;
                else
                    limit = K_init - K_end - lp_next + lp_act;
                end

                if verb==2
                    fprintf('%f %f %f %f ',lp_act,lp_next,exp(limit),a);
                    pause
                end

                if a < exp(limit)
                    % accept the sample
                    g = g_next;
                    lp_act = lp_next;
                    accept = true;
                    if verb==2
                        fprintf('accept\n');
                    end
                else
                    rr = rr + 1;
                    if verb==2
                        fprintf('reject\n');
                    end
                end
            end
        elseif strcmp(g_sampler,'slice')
            logpdf = @(g) gestaltLogPostG(g,v,ge);           
            [g_part,rr_act] = sliceSample(g(1:ge.k-1,1),logpdf,stepsize,'plot',plot);
            g = [g_part; 1-sum(g_part)];
            rr = rr + rr_act;
        end
        
        % uncomment this and comment out the similar line in the beginning if
        % you want to reverse the order of sampling from the conditionals
        % v = gestaltPostVRnd(ge,xind,g);
        
        % store the combined sample
        s(i,:) = [g' v'];
    end
    if verb==1
        fprintf('\n');
    end
    
    % calculate the rejection rate
    rr = rr / (rr + N);
    
    % discard burn-in stage
    if burn > 0
        s = s(burn+1:N,:);
    end
end