function loglike = gestaltLogLikeV(V,g,ge,precision)
    if ndims(V) == 3
        V = reshape(V,ge.B,ge.Dv);
    end
    B = size(V,1);        
    
    if ~precision
        Cv = componentSum(g,ge.cc);
        [~,err] = chol(Cv);
        if err > 0
            lp = -Inf;
            return;
        end
    else
        P = componentSum(g,ge.pc);
    end        
    
    quad = 0;
    for b=1:B
        vb = V(b,:)';
        
        if ~precision
            quad = quad + vb' * (Cv \ vb);
            %this should be faster
%             opts.LT = true;
%             opts.UT = false;
%             temp = linsolve(U',vb,opts);
%             opts.LT = false;
%             opts.UT = true;
%             rightvec = linsolve(U,temp,opts);
%             quad = quad + vb' * rightvec;
        else
            quad = quad + vb' * P * vb;
        end
    end
    if ~precision
        loglike = (-1/2) * ( B* log(det(Cv)) + quad );    
    else
        loglike = (-1/2) * ( B* log(1/det(P)) + quad );
    end
end