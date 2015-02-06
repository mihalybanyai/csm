function [V,m] = gestaltPostVRnd(ge,xind,g,z,precision)

    % construct the covariance and mean of the conditional posterior over v
    sAA = ((z*z)/ge.obsVar) * ge.AA;
    if ~precision
        Cv = componentSum(g,ge.cc);        
        %icv = Cv \ eye(ge.Dv);
        %icovm = sAA + icv;
        %icovm = sAA + inv(Cv);
        %covm = icovm \ eye(ge.Dv);
        icv = inv(Cv);
        covm = inv(sAA + icv);       
        % viewImage(cov);
    else
        P = componentSum(g,ge.pc);
        covm = inv(sAA + P);
    end
        
    V = zeros(ge.B,ge.Dv);
    for b=1:ge.B        
        ATx = ge.A' * reshape(ge.X(xind,b,:),ge.Dv,1);
        m = (z/ge.obsVar) * covm * ATx;
        V(b,:) = mvnrnd(m',covm);
    end
end