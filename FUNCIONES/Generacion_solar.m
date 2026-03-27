function [MC_dia_noche, Sn_FNCER, a_dia, b_dia] = Generacion_solar(data, Sn, Sn_celda, FP)
% Calcula los momentos estadísticos de la potencia generada por una fuente
% solar mediante simulación Monte Carlo con distribución Beta de irradiancia

% Recibe:
%   data: parámetros Beta [a_dia, b_dia, a_noche, b_noche] solo se usan
%         a_dia y b_dia (parámetros adimensionales de forma). Type: vector (1x4) double 
%         O una ruta a un archivo .csv con columnas [año, mes, día, hora, minuto, GHI] Type: string.
%         Si es CSV, calcula a y b.
%   Sn: capacidad del generador síncrono a reemplazar [MW]. Type: double.
%   Sn_celda: capacidad nominal de una celda solar [MW]. Type: double.
%   FP: factor de planta. Type: double.

% Retorna:
%   MC_dia_noche: tabla con momentos centrales (Media, Desviación Estándar,
%                 Sesgo, Curtosis) para día y noche. Noche siempre es 0.
%                 Type: table (2x5).
%   Sn_FNCER: capacidad nominal del parque eólico [MW]. Type: double.

%   Caracterización basada en el paper "Optimal power flow solutions incorporating 
%   stochastic wind and solar power" de Partha P. Biswas, P.N. Suganthan, Gehan A.J. 
%   Amaratunga.

    % Parametrización base: constantes del modelo
    G = 800; % W/m2
    Rc = 120; % W/m2
    GHI_max = 1000;  % Irradiancia máxima física W/m²

    % Extracción de parámetros Beta
    if ischar(data) || isstring(data)

        % Leer CSV y calcular a, b por método de momentos
        datos = readmatrix(data);
        GHI = datos(:, 6);
        
        % Día: GHI > 0
        GHI_dia = GHI(GHI > 0);
        
        % Normalizar
        x = GHI_dia / GHI_max;
        
        % Evitar 0 y 1 exactos
        x = min(max(x,1e-6),1-1e-6);
        
        % Ajuste Beta (MLE)
        parametros = betafit(x);     % phat = [a b]
        a_dia = parametros(1);
        b_dia = parametros(2);

    else

        a_dia = data(1);
        b_dia = data(2);
        
    end

    % Generación de irradiancias aleatorias mediante distribución Beta
    GHI_dia = betainv(rand(10000,1), a_dia, b_dia)* GHI_max;
        
    % Modelar el parque solar
    Sn_FNCER = (Sn/FP); % Potencia nominal del parque eólico. [MW]

    n = round(Sn_FNCER/Sn_celda); % Número de celdas que tendrá el parque
    
    % Calcular la potencia generada durante el día
    potencia_dia = zeros(length(GHI_dia),1);
    
    for i = 1:length(potencia_dia)

        if (GHI_dia(i) > 0 && GHI_dia(i) < Rc)
            potencia_dia(i) = Sn_celda*(GHI_dia(i)^2)/(G*Rc);
        end

        if GHI_dia(i) >= Rc
            potencia_dia(i) = Sn_celda*(GHI_dia(i))/(G);
        end     
       
    end  

    p_dia = min(potencia_dia, Sn_celda);
      
    % Cálculo de momentos estadísticos para el parque completo
    % Escalamiento por número de turbinas y cálculo de momentos centrales
        
    % Estadísticos del período diurno
    m_dia = mean(p_dia); 
    d_dia = std(p_dia);
    cv_dia = d_dia/m_dia;
    media_dia = n*m_dia; % Media para el día
    des_dia = cv_dia*media_dia; % Desviacion para el día
    sesgo_dia = skewness(p_dia); % Sesgo para el día
    curtosis_dia = kurtosis(p_dia); % Curtosis para el día        
      
    % Consolidación de resultados en tabla
    Media   = [media_dia(:);   0];
    DesvE   = [des_dia(:);     0];
    Sesgo   = [sesgo_dia(:);   0];
    Curtosis= [curtosis_dia(:); 0];
    
    Periodo = ["Día"; "Noche"];
    
    MC_dia_noche = table(Periodo, Media, DesvE, Sesgo, Curtosis);
    MC_dia_noche.Properties.VariableNames = ["Periodo", "Media","Desviación Estándar","Sesgo","Curtosis"];

end