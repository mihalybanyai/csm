function ll = gestaltLogLikelihood(ge,L,data)
    % approximated, up to a constant
    % get L samples from a k-dimensional symmetric dirichelet prior for g
    
    ll = 0;
    if data == 0
        nseq = 1:ge.N;
        N = ge.N;
    else
        nseq = [data];
        N = 1;
    end
    G = symmetricDirichlet(ge.sparsity,ge.k,N*L);
    for i=1:N
        n = nseq(i);
        samp_coeffs = zeros(1,L);
        samp_exps = zeros(1,L);
        for s=1:L
            batch_coeffs = zeros(1,ge.B);
            batch_exps = zeros(1,ge.B);
            g = G((i-1)*L+s,:)';
            Cv = componentSum(g,ge.cc);
            C = ge.obsVar * eye(ge.Dx) + ge.A * Cv * ge.A';
            [~,err] = chol(C);
            if err == 0 && isequal(C,C')                                          
                for b=1:ge.B                
                    x = squeeze(ge.X(n,b,:));                                
                    p = mvnpdf(x,zeros(size(x)),C);                               
                    [batch_coeffs(1,b),batch_exps(1,b)] = sciNot(p);                                
                end            
            end
            [samp_coeffs(1,s),samp_exps(1,s)] = sciProd(batch_coeffs,batch_exps);            
        end 
        [datum_coeff,datum_exp] = sciSum(samp_coeffs,samp_exps);
        ll = ll + log10(datum_coeff) + datum_exp;       
    end
end

function [coefficient,exponent] = sciNot(a)
    [coefficient,exponent] = strread(strrep(sprintf('%E',a),'E','#'),'%f#%f');
end

function [coefficient,exponent] = sciSum(coeffs,exps)
    exponent = 0;
    coefficient = 0;
    for i=1:size(coeffs,2)
        [coefficient,exponent] = sumSciNot(coefficient,exponent,coeffs(1,i),exps(1,i));
    end
end

function [coefficient,exponent] = sumSciNot(c1,e1,c2,e2)    
    if c1 == 0 && e1 == 0
        coefficient = c2;
        exponent = e2;
        return;
    elseif c2 == 0 && e2 == 0
        coefficient = c1;
        exponent = e1;
        return;
    end
    exponent = max(e1,e2);
    expdiff = abs(e1-e2);
    if(e1 > e2)
        coefficient = c1 + 10^(-expdiff) * c2;
    else
        coefficient = c2 + 10^(-expdiff) * c1;
    end
    [coefficient,ex] = sciNot(coefficient);    
    exponent = exponent + ex;
end

function [coefficient,exponent] = sciProd(a,e)
    exponent = 0;
    coefficient = 1;
    for i=1:size(a,2)        
        coefficient = coefficient * a(i);
        if coefficient >= 10
            exponent = exponent + 1;
            coefficient = coefficient / 10;
        elseif coefficient <= -10
            exponent = exponent - 1;
            coefficient = coefficient / 10;
        end
    end    
    exponent = exponent + sum(e,2);
end