function whitened = whitenImages(images)
    % whiten images: http://www.mathworks.com/matlabcentral/fileexchange/34471-data-matrix-whitening/content/whiten.m
    % each image should be a row vector
%     A = images'*images;
%     [V,D,~] = svd(A);
%     whMat = sqrt(size(images,1)-1)*V*sqrtm(inv(D + eye(size(D))*0.0001))*V';
%     whitened = images*whMat;
    
    N=sqrt(size(images,2));
    M=size(images,1);

    [fx, fy]=meshgrid(-N/2:N/2-1,-N/2:N/2-1);
    rho=sqrt(fx.*fx+fy.*fy);
    f_0=0.4*N;
    filt=rho.*exp(-(rho/f_0).^4);
    
    whitened = zeros(size(images))';
    
    for i=1:M        
        If=fft2(reshape(images(i,:),N,N));
        imagew=real(ifft2(If.*fftshift(filt)));
        whitened(:,i)=reshape(imagew,N^2,1);
    end

    whitened=sqrt(0.1)*whitened/sqrt(mean(var(whitened)))';    
end