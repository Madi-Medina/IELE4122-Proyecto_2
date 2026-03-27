function[p, w, pc] = PEM(typeFERNC, Sn_FERNC, CM, VA,  Co_FERNC, dn)
% Genera puntos de concentración mediante el método Point Estimate Method
% (PEM 2m+1) para modelar la incertidumbre de m fuentes renovables

% Recibe:
%   typeFERNC: tipo de cada fuente (1=eólica, 2=solar). Type: vector (mx1)
%              double.
%   Sn_FERNC: capacidad nominal de cada fuente [MW]. Type: vector (mx1)
%             double.
%   CM: momentos centrales (media, desviación, sesgo, curtosis). Type:
%       matrix (4xm) double.
%   VA: tipo de variables aleatorias (1=independientes, 0=correlacionadas).
%       Type: double.
%   Co_FERNC: matriz de correlación entre fuentes. Type: matrix (mxm)
%             double.
%   dn: período (1=día, 0=noche). Type: double.

% Retorna:
%   p: puntos de concentración de potencia por fuente [MW]. Type: matrix
%      (mx3) double.
%   w: pesos asociados a cada punto. Type: matrix (mx3) double.
%   pc: matriz completa [número_punto | potencias_fuentes | peso_total].
%       Type: matrix ((2m+1)x(m+2)) double.

if dn == 1 % período diurno

    if isempty(typeFERNC) == 0 % Verificar que existan fuentes renovables a procesar
        
        % Extracción de momentos centrales de la matriz CM 
    
        mean_FERNC = CM(1,:)'; % vector con la media de cada fuente [MW]
    
        sdesv_FERNC = CM(2,:)'; % vector con la desviación estándar de cada fuente [MW]
    
        skew_FERNC = CM(3,:)'; % vector con los coeficientes de asimetría (sesgo) de cada fuente
    
        kurt_FERNC = CM(4,:)'; % vector con las curtosis de cada fuente
    
         % Aplicación de PEM según tipo de variables aleatorias
    
        if VA == 1 % variables independientes
    
            m = length(typeFERNC); % número de fuentes renovables
            len = 2*m+1; % número de puntos de concentración
            pc = zeros(len,3); 
            pc(:,1) = 1:len;    
    
            % Inicialización de matrices para el método PEM
            e = zeros(m,3);
            p = zeros(m,3); 
            w = zeros(m,3);
        
            for i = 1:m
    
                for k = 1:3 
    
                    if k == 3
    
                        e(i,k)=0;
    
                    end
    
                    if k ~= 3
    
                        e(i,k) = (skew_FERNC(i,1)/2) + ((-1)^(3-k))*sqrt(kurt_FERNC(i,1)-((3/4)*(skew_FERNC(i,1))^2));
    
                    end
    
                end
    
            end    
   
            % Ubicación del punto de concentración (potencia inyectada)
            % p(:,1) --> mean + e(:,1)*desv
            % p(:,2) --> mean + e(:,2)*desv
            % p(:,3) --> mean + 0

            for i = 1:m
    
                for k = 1:3
    
                    p(i,k)= mean_FERNC(i,1) + (e(i,k)*sdesv_FERNC(i,1));
    
                end
    
            end
    
            % Peso del punto de concentración    
            for i = 1:m
    
                for k = 1:3 
    
                    if(k == 3)
    
                        w(i,k) = (1/m)-(1/(kurt_FERNC(i,1)-((skew_FERNC(i,1))^2)));
    
                    else
    
                        w(i,k) = ((-1)^(3-k))/(e(i,k)*(e(i,1)-e(i,2)));
    
                    end
    
                end
    
            end    
    
        else % variables correlacionadas
    
            % Construcción de la matriz de covarianza Cp   
    
            Cp = zeros(length(sdesv_FERNC),length(sdesv_FERNC));
    
                for i  = 1:length(sdesv_FERNC)
    
                    for j = 1:length(sdesv_FERNC) 
    
                        if(i == j)
    
                            Cp(i,j) = sdesv_FERNC(i)^2;
    
                        end
    
                        if(i ~= j)
    
                            Cp(i,j) = Co_FERNC(i,j)*sdesv_FERNC(i)*sdesv_FERNC(j);
    
                        end
                    end
                end
    
            % Descomposición de Cholesky y transformación al espacio no correlacionado
    
            L_chol = chol(Cp)';
            B = inv(L_chol);
            Cq = B*Cp*B';
    
            % Cambio de base de los estadísticos 
    
            sdesv_q = zeros(length(sdesv_FERNC),1);
    
            for i = 1:length(sdesv_FERNC)
    
                for j = 1:length(sdesv_FERNC)
    
                    if i == j
    
                    sdesv_q(i) = sqrt(Cq(i,j));
    
                    end
    
                end
            end
    
            mean_q = B*mean_FERNC;  
    
            skew_q = zeros(length(sdesv_FERNC),1); 
    
            kurt_q = zeros(length(sdesv_FERNC),1);    
    
            for i = 1:length(sdesv_FERNC) 
    
                for j =1:length(sdesv_FERNC)
    
                    skew_q(i) = skew_q(i)+((B(i,j)^3)*skew_FERNC(j)*sdesv_FERNC(j)^3);
    
                    kurt_q(i) = kurt_q(i)+((B(i,j)^4)*kurt_FERNC(j)*sdesv_FERNC(j)^4);
    
                end
    
            end 
    
            m = length(typeFERNC); % número de fuentes renovables
            len = 2*m+1; % número de puntos de concentración
            pc = zeros(len,3); 
            pc(:,1) = 1:len;    
    
            % Inicialización de matrices para el método PEM
            e = zeros(m,3);
            p = zeros(m,3);
            w = zeros(m,3);
      
            for i = 1:m
    
                for k = 1:3 
    
                    if k == 3
    
                        e(i,k)=0;
    
                    end
    
                    if k ~= 3
    
                        e(i,k) = (skew_q(i,1)/2) + ((-1)^(3-k))*sqrt(kurt_q(i,1)-((3/4)*(skew_q(i,1))^2));
    
                    end
    
                end
    
            end
    
     
            % Ubicación del punto de concentración (potencia inyectada)
            % p(:,1) --> mean + e(:,1)*desv
            % p(:,2) --> mean + e(:,2)*desv
            % p(:,3) --> mean + 0

            for i = 1:m
    
                for k = 1:3
    
                    p(i,k)= mean_q(i) + (e(i,k)*sdesv_q(i));
    
                end
    
            end
    
            p = inv(B)*p; % Retorno al espacio original mediante transformación inversa
    
            % Peso del punto de concentración     
            for i = 1:m
    
                for k = 1:3 
    
                    if(k == 3)
    
                        w(i,k) = (1/m)-(1/(kurt_q(i,1)-((skew_q(i,1))^2)));
    
                    else
    
                        w(i,k) = ((-1)^(3-k))/(e(i,k)*(e(i,1)-e(i,2)));
    
                    end
    
                end
    
            end

        end
    
        % Aplicación de límites físicos de potencia (0 ≤ p ≤ Sn_FERNC)

        for i = 1:length(Sn_FERNC)

            for j = 1:3

                if p(i,j) < 0
                   p(i,j) = 0;
                end

                if p(i,j) >= Sn_FERNC(i)
                   p(i,j) = Sn_FERNC(i);
                end            


            end

        end   
         
        % Construcción de la matriz con los puntos de concentración (desagregada) 
        % Estructura: [número_punto | potencia_fuente_1 ... potencia_fuente_m | peso]
        pc = zeros(2*length(Sn_FERNC) + 1, 2+length(Sn_FERNC)); % Filas (2m+1)
        pc(1,end) = sum(w(:,end));
    
        for i = 1:2*length(Sn_FERNC) + 1
            pc(i,1) = i;
            pc(i,2:length(Sn_FERNC)+1) = p(:,3)';
        end
        
        for i = 1:length(Sn_FERNC)
            pc(2*i:2*i+1,1+i) = p(i,1:2)';
            pc(2*i:2*i+1,end) = w(i,1:2)';
        end
     
    end

elseif dn == 0 % período nocturno

    if isempty(typeFERNC) == 0 % Verificar que existan fuentes renovables a procesar
    
        % Extracción de momentos centrales de la matriz CM  
        
        mean_FERNC = CM(1,:)'; % vector con la media de cada fuente [MW]
                                                 
        sdesv_FERNC = CM(2,:)'; % vector con la desviación estándar de cada fuente [MW]
                                                  
        skew_FERNC = CM(3,:)'; % vector con los coeficientes de asimetría (sesgo) de cada fuente
                                                 
        kurt_FERNC = CM(4,:)'; % vector con las curtosis de cada fuente
           
        % Identificación de fuentes solares (tipo 2)
        
        cont = 0;
        del = [];
        
            for i = 1:length(typeFERNC)
        
                if typeFERNC(i) == 2
                    cont = cont + 1;
                    del(cont) = i;      
                end
        
            end
            
           % Eliminación de la información de las fuentes solares de todos los vectores y matrices
           typeFERNC(del) = [];
           Sn_FERNC(del) = [];
           mean_FERNC(del) = [];
           sdesv_FERNC(del) = [];
           skew_FERNC(del) = [];
           kurt_FERNC(del) = [];
           Co_FERNC(:,del) = [];
           Co_FERNC(del,:) = [];
       
    end
    
    
    if isempty(typeFERNC) == 0 % Verificar nuevamente después de eliminar solares
        
        % Aplicación de PEM según tipo de variables aleatorias
    
        if VA == 1 % variables independientes
            
            m = length(typeFERNC); % número de fuentes renovables
            len = 2*m+1; % número de puntos de concentración
                
            pc = zeros(len,3); 
            pc(:,1) = 1:len;    
            
            % Inicialización de matrices para el método PEM
            e = zeros(m,3);
            p = zeros(m,3);
            w = zeros(m,3);
                        
            for i = 1:m
            
                for k = 1:3 
        
                    if k == 3
        
                        e(i,k)=0;
        
                    end
                    
                    if k ~= 3
        
                        e(i,k) = (skew_FERNC(i,1)/2) + ((-1)^(3-k))*sqrt(kurt_FERNC(i,1)-((3/4)*(skew_FERNC(i,1))^2));
        
                    end
        
                end
                
            end
            
            % Ubicación del punto de concentración (potencia inyectada)
            % p(:,1) --> mean + e(:,1)*desv
            % p(:,2) --> mean + e(:,2)*desv
            % p(:,3) --> mean + 0
        
            for i = 1:m
                
                for k = 1:3
        
                    p(i,k)= mean_FERNC(i,1) + (e(i,k)*sdesv_FERNC(i,1));
        
                end
                
            end
            
            % Peso del punto de concentración            
            for i = 1:m
                
                for k = 1:3 
        
                    if(k == 3)
        
                        w(i,k) = (1/m)-(1/(kurt_FERNC(i,1)-((skew_FERNC(i,1))^2)));
        
                    else
        
                        w(i,k) = ((-1)^(3-k))/(e(i,k)*(e(i,1)-e(i,2)));
        
                    end
                
                end
                
            end
            
        else % variables correlacionadas
                
            % Construcción de la matriz de covarianza Cp    
            
            Cp = zeros(length(sdesv_FERNC),length(sdesv_FERNC));
               
                for i  = 1:length(sdesv_FERNC)
                    
                    for j = 1:length(sdesv_FERNC) 
                        
                        if(i == j)
                            
                            Cp(i,j) = sdesv_FERNC(i)^2;
                            
                        end
                        
                        if(i ~= j)
                            
                            Cp(i,j) = Co_FERNC(i,j)*sdesv_FERNC(i)*sdesv_FERNC(j);
                            
                        end
                    end
                end
            
            % Descomposición de Cholesky y transformación al espacio no correlacionado
                        
            L_chol = chol(Cp)';
            B = inv(L_chol);
            Cq = B*Cp*B';
            
            % Cambio de base de los estadísticos
            
            sdesv_q = zeros(length(sdesv_FERNC),1);
            
            for i = 1:length(sdesv_FERNC)
                
                for j = 1:length(sdesv_FERNC)
                    
                    if i == j
                        
                    sdesv_q(i) = sqrt(Cq(i,j));
                    
                    end
               
                end
            end
            
            mean_q = B*mean_FERNC;  
            
            skew_q = zeros(length(sdesv_FERNC),1); 
                                                 
            kurt_q = zeros(length(sdesv_FERNC),1);    
           
            for i = 1:length(sdesv_FERNC) 
                
                for j =1:length(sdesv_FERNC)
                    
                    skew_q(i) = skew_q(i)+((B(i,j)^3)*skew_FERNC(j)*sdesv_FERNC(j)^3);
                    
                    kurt_q(i) = kurt_q(i)+((B(i,j)^4)*kurt_FERNC(j)*sdesv_FERNC(j)^4);
                    
                end
                
            end 
            
            m = length(typeFERNC); % número de fuentes renovables
            len = 2*m+1; % número de puntos de concentración
            pc = zeros(len,3); 
            pc(:,1) = 1:len;    
            
            % Inicialización de matrices para el método PEM
            e = zeros(m,3);
            p = zeros(m,3);
            w = zeros(m,3);
            
            for i = 1:m
            
                for k = 1:3 
        
                    if k == 3
        
                        e(i,k)=0;
        
                    end
                    
                    if k ~= 3
        
                        e(i,k) = (skew_q(i,1)/2) + ((-1)^(3-k))*sqrt(kurt_q(i,1)-((3/4)*(skew_q(i,1))^2));
        
                    end
        
                end
                
            end
            
            % Ubicación del punto de concentración (potencia inyectada)
            % p(:,1) --> mean + e(:,1)*desv
            % p(:,2) --> mean + e(:,2)*desv
            % p(:,3) --> mean + 0
        
            for i = 1:m
                
                for k = 1:3
        
                    p(i,k)= mean_q(i) + (e(i,k)*sdesv_q(i));
        
                end
                
            end
            
            p = inv(B)*p; % Retorno al espacio original mediante transformación inversa
                        
            % Peso del punto de concentración            
            for i = 1:m
                
                for k = 1:3 
        
                    if(k == 3)
        
                        w(i,k) = (1/m)-(1/(kurt_q(i,1)-((skew_q(i,1))^2)));
        
                    else
        
                        w(i,k) = ((-1)^(3-k))/(e(i,k)*(e(i,1)-e(i,2)));
        
                    end
                
                end
                
            end

        end
            
        % Aplicación de límites físicos de potencia (0 ≤ p ≤ Sn_FERNC)
       
        for i = 1:length(Sn_FERNC)
            
            for j = 1:3
               
                if p(i,j) < 0
                   p(i,j) = 0;
                end
                
                if p(i,j) >= Sn_FERNC(i)
                   p(i,j) = Sn_FERNC(i);
                end            
                
                
            end
            
        end      
                       
        % Construcción de la matriz con los puntos de concentración (desagregada)
        % Estructura: [número_punto | potencia_fuente_1 ... potencia_fuente_m | peso]             
        pc = zeros(2*length(Sn_FERNC) + 1, 2+length(Sn_FERNC)); %
        pc(1,end) = sum(w(:,end));
        
        for i = 1:2*length(Sn_FERNC) + 1
            pc(i,1) = i;
            pc(i,2:length(Sn_FERNC)+1) = p(:,3)';
        end
        
        for i = 1:length(Sn_FERNC)
            pc(2*i:2*i+1,1+i) = p(i,1:2)';
            pc(2*i:2*i+1,end) = w(i,1:2)';
        end
    
    end

end
      
end