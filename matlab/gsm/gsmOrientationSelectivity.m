function gsmOrientationSelectivity(A,C,sigma_x,thetaRes,loadStuff,match,scalarprod)

    setrandseed(1);
    nFilt = size(A,2);
    imsize = sqrt(size(A,1));
    lambdaRes = 3;
    phaseRes = 10;
    spaceRes = 4;
    lambdaVals = linspace(2,imsize/2,lambdaRes);
    thetaVals = linspace(0,180,thetaRes);
    phaseVals = linspace(0,1,phaseRes);
    xVals = round(linspace(1,imsize,spaceRes));
    yVals = round(linspace(1,imsize,spaceRes));
        
    if loadStuff
        load('save_gsmorient.mat');
    else
        responses = zeros(nFilt,thetaRes);        
    end
    
    nPlot = min(10,nFilt);
    nRow = 2;
    plotIndices = [];
    for r = 1:nRow
        plotIndices = [plotIndices; chooseKfromN(nPlot,nFilt)];
    end
    toPlot = false(nFilt,1);
    toPlot(plotIndices(:)) = true;
    plotcount = 1;
    
    z = 1;
    gsmPostMeanTransform = (z / sigma_x^2) * stableInverse(stableInverse(C) + (z^2 / sigma_x^2) * (A'*A)) * A';
        
    if ~loadStuff         
        for t = 1:thetaRes
            printCounter(t,'maxVal',thetaRes,'stringVal','Orientation');    
            theta_responses = zeros(lambdaRes,nFilt);
            for l = 1:lambdaRes                
                if strcmp(match,'grating')
                    lambda_responses = zeros(phaseRes,nFilt);
                    for p = 1:phaseRes                    
                        act_grat = grating(lambdaVals(l),thetaVals(t),phaseVals(p),imsize);                            
                        act_stim = act_grat(:);
                        act_stim = act_stim ./ std(act_stim);
                        %act_resp = gsmPostMeanTransform * act_stim;
                        if scalarprod
                            act_resp = A' * act_stim;
                        else
                            %act_resp = gsmPostMeanTransform * act_stim;
                            act_resp = gsmPosteriorV(act_stim,A,C,sigma_x,2,2,10);
                        end
                        %responses(:,t) = responses(:,t) + act_resp;
                        lambda_responses(p,:) = act_resp;                        
                    end                    
                elseif strcmp(match,'gabor')
                    lambda_responses = zeros(spaceRes^2,nFilt);
                    for x = 1:spaceRes
                        for y = 1:spaceRes
                            act_gabor = gaborfilter(lambdaVals(l),thetaVals(t),imsize,xVals(x),yVals(y));
                            act_stim = act_gabor(:);
                            act_stim = act_stim ./ std(act_stim);
                            %act_resp = gsmPostMeanTransform * act_stim;
                            %responses(:,t) = responses(:,t) + act_resp;                            
                            if scalarprod
                                act_resp = A' * act_stim;
                            else
                                act_resp = gsmPostMeanTransform * act_stim;
                            end
                            lambda_responses((x-1)*spaceRes+y,:) = act_resp;
                        end
                    end
                else
                    error('no valid match');
                end
                theta_responses(l,:) = max(lambda_responses)';                
            end
            responses(:,t) = max(theta_responses)';
        end
    end
    for i = 1:nFilt
        f = A(:,i);
        if toPlot(i)
            rownum = 2;
            actbundle = ceil(plotcount / nPlot);
            filterrow = (actbundle-1)* rownum + 1;
            tuningrow = actbundle * rownum;
            actcol = plotcount - (actbundle-1) * nPlot;
            
            subplot(rownum*nRow,nPlot,(filterrow-1)*nPlot + actcol);
            viewImage(f,'useMax',true);
            title(sprintf('Filter no. %d',i));            
            
            subplot(rownum*nRow,nPlot,(tuningrow-1)*nPlot + actcol);
            plot(thetaVals,responses(i,:))
            title('Orientation tuning');
            
            plotcount = plotcount + 1;
        end
    end    
    
    if ~loadStuff
        save('bin/save_gsmorient.mat','responses');
    end
    
end

function img = gaborfilter(lambda,theta,imSize,xc,yc) 
    thetaRad = (theta / 360) * 2*pi;
    lambda = lambda - 1;
    px = xc/imSize;
    py = yc/imSize;
    [~,~,img] = gabor('theta',thetaRad,'lambda',lambda,'width',imSize,'height',imSize,'px',px,'py',py,'Sigma',lambda/2);             
end
