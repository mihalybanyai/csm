function cc = gestaltCovariances(k,R)
    fprintf('Calculating covariance components\n');
    % vertical lines
    Dx = size(R,2);
    imsizex = floor(sqrt(Dx));
    imsizey = ceil(sqrt(Dx));
    Dv = size(R,1);
    %fprintf('Calculating R\n');
    % R = pinv(A'*A)*A';
    % the gestalts should be placed over or watermarked onto natural images
    shift = floor(imsizex/3);
    width = max(1,floor(shift/3));
    margin = width;
    N = max(Dx,Dv) + 1;
    for g = 1:k
        fprintf('..Component %d\n', g);
        act_shift = g*shift;
        vs = zeros(N,Dv);
        X = mvnrnd(zeros(N,Dx),eye(Dx));
        fprintf('....%d/', N);
        for i=1:N
            printCounter(i);
            x = reshape(X(i,:),imsizex,imsizey);
            x(margin:imsizex-margin,act_shift:act_shift+width) = x(margin,act_shift);
            x = reshape(x,1,Dx);
            vs(i,:) = x * R';
        end
        fprintf('\n....Calculating covariance\n');
        cc{g} = cov(vs);
    end
end