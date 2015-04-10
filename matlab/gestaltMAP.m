function [V,G,Z,delta,gcourse,zcourse,loglike] = gestaltMAP(ge,fix_v,fix_z,v_init,drawGradients)
    close all;
     if ge.B ~= 1
         error('not implemented for B>1');
     end
    X = reshape(ge.X,ge.N,ge.Dx);
    N = size(X,1);
    
    if fix_v
        learning_rate_v = 0;
    else
        learning_rate_v = 0.0001;
    end
    
    if strcmp(v_init,'data')
        V = (ge.A'*X')';
    elseif strcmp(v_init,'true')
        V = ge.V;
    else
        V = v_init;
    end
    
    if fix_z
        learning_rate_z = 0;
        Z = ge.Z;
    else
        learning_rate_z = 0.001;
        Z = 1 * ones(N,1);
    end
    
    learning_rate_g = 0.01;
    G = rand(N,ge.k);
    minval = 0.01;
    
    delta = {};
    gcourse = {};
    zcourse = {};
    loglike = {};
    
    for i=1:N
        act_x = X(i,:);
        act_v = V(i,:);
        norm_v = reshape(ge.V(i,1,:),1,ge.Dv);
        norm_v = norm_v / norm(norm_v);
        
        act_g = G(i,:)';
        act_z = Z(i,1);

        % gradient ascent
        convergence = false;
        counter = 1;
        actdelta = [];
        actgcourse = [];
        actzcourse = [];
        actloglike = [];
        while ~convergence            
            counter = counter+1; 

            grad = gestaltFullLogPosteriorGrad(ge,act_x,act_v,act_g,act_z,[]);
            grad_G = grad(1:ge.k,1);
            grad_V = grad(ge.k+1:end-1,1);
            grad_Z = grad(end,1);
%                 
%                 pref_shift = 0.1;
%                 if max(abs(grad_G)) * learning_rate_g > pref_shift                    
%                     learning_rate_g = pref_shift / max(abs(grad_G))
%                     learning_rate_z = pref_shift / max(abs(grad_Z))
%                     learning_rate_v = pref_shift / max(abs(grad_V))
%                 end
                
            if rem(counter-2,drawGradients) == 0
                imgmax = 1.1;
                imgstep = 0.04;                    
                probcutoff = 70;
                cutoff = 1;

                gx = 0.01:imgstep:imgmax;
                if max(act_g) > imgmax
                    gx = gx + max(act_g) - imgmax/2;
                end
                gg1 = zeros(length(gx));
                gg2 = zeros(length(gx));
                for k=1:length(gx)
                    printCounter(k,'maxVal',length(gx),'StringVal','e')
                    for j=1:length(gx);
                        gradient = gestaltFullLogPosteriorGrad(ge,act_x,act_v,[gx(k);gx(j)],act_z,[]);
                        gg1(k,j) = gradient(1);
                        gg2(k,j) = gradient(2);
                    end
                end           

                if ~exist('fhg1') 
                    fhg1 = figure;
                else 
                    figure(fhg1);
                end

                subplot(1,4,1);
                pg = zeros(length(gx));
                for k=1:length(gx)
                    printCounter(k,'maxVal',length(gx),'StringVal','e');
                    for j=1:length(gx);
                        pg(k,j) = gestaltFullLogPosterior(ge,reshape(act_x,ge.B,ge.Dx),reshape(act_v,ge.B,ge.Dv),[gx(k);gx(j)],act_z,[]);
                    end
                end
                pg (pg < max(pg(:))*0.01*probcutoff) = max(pg(:))*0.01*probcutoff;            
                imagesc(gx(cutoff:end),gx(cutoff:end),pg(cutoff:end,cutoff:end))   
                hold on;
                plot(act_g(2),act_g(1),'-gx','MarkerSize',20,'LineWidth',3);

                subplot(1,4,2);
                imagesc(gx(cutoff:end),gx(cutoff:end),gg1(cutoff:end,cutoff:end))
                maxval = max([ max(max(gg1(cutoff:end,cutoff:end))) abs( min(min(gg1(cutoff:end,cutoff:end))) ) ]);
                colorscale = 1e-5;
                caxis(colorscale*[-maxval maxval]);
                title('1')
                hold on;
                plot(act_g(2),act_g(1),'-gx','MarkerSize',20,'LineWidth',3);

                subplot(1,4,3);
                imagesc(gx(cutoff:end),gx(cutoff:end),gg2(cutoff:end,cutoff:end))
                maxval = max([ max(max(gg2(cutoff:end,cutoff:end))) abs( min(min(gg2(cutoff:end,cutoff:end))) ) ]);                
                caxis(colorscale*[-maxval maxval]);
                title('2')
                hold on;
                plot(act_g(2),act_g(1),'-gx','MarkerSize',20,'LineWidth',3);      
                
                subplot(1,4,4);
                zx = 0.01:0.02:7;
                pz = zeros(length(zx),1);
                for j=1:length(zx)
                    pz(j) = gestaltFullLogPosterior(ge,act_x,act_v,act_g,zx(j),[]);
                end
                plot(zx,pz)                                

                pause
            end

            prev_g = act_g;

            max_shift_g = 0.1;
            act_v = act_v + learning_rate_v * grad_V';
            act_g = max(act_g + min(learning_rate_g * grad_G,max_shift_g),minval*ones(ge.k,1));
            act_z = max(act_z + learning_rate_z * grad_Z,minval);
            lp = gestaltFullLogPosterior(ge,act_x,act_v,act_g,act_z,[]);

            %maxdelta = sum((prev_g-act_g).^2);
            maxdelta = max((prev_g-act_g).^2);
            if maxdelta < 1e-6 || counter == 1000
                convergence = true;
                fprintf('Convergence achieved in %d steps.\n',counter-1);
            end

            actnorm = reshape(act_v,1,ge.Dv);
            actnorm = actnorm/norm(actnorm);
            angle = actnorm * norm_v';
            actdelta = [actdelta angle];
            actgcourse = [actgcourse act_g];
            actzcourse = [actzcourse act_z];
            actloglike = [actloglike lp];

        end
        
        delta{end+1} = actdelta;
        gcourse{end+1} = actgcourse;
        zcourse{end+1} = actzcourse;
        loglike{end+1} = actloglike;
        V(i,:) = act_v;
        G(i,:) = act_g';
        Z(i,1) = act_z;
    end
end