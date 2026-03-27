function [MC_dia_noche, Sn_FNCER] = Generacion_eolica(data, Sn, Sn_turbina, info_Turbina, FP)
% Calcula los momentos estadísticos de la potencia generada por una fuente
% eólica mediante simulación Monte Carlo con distribución Weibull del viento

% Recibe:
%   data: parámetros Weibull [a_dia, b_dia, a_noche, b_noche] donde a es
%         escala [m/s] y b es forma. Type: vector (1x4) double.
%   Sn: capacidad del generador síncrono a reemplazar [MW]. Type: double.
%   Sn_turbina: capacidad nominal de una turbina [MW]. Type: double.
%   info_Turbina: curva de potencia de la turbina [velocidad(m/s),
%                 potencia(MW)]. Type: matrix (nx2) double.
%   FP: factor de planta. Type: double. 

% Retorna:
%   MC_dia_noche: tabla con momentos centrales (Media, Desviación, Sesgo,
%   Curtosis) para día y noche. Type: table (2x5).
%   Sn_FNCER: capacidad nominal del parque eólico [MW]. Type: double.


% Extracción de parámetros Weibull
a_dia = data(1);    % parámetro de escala día [m/s]
b_dia = data(2);    % parámetro de forma día
a_noche = data(3);  % parámetro de escala noche [m/s]
b_noche = data(4);  % parámetro de forma noche

% Generación de velocidades de viento aleatorias mediante distribución Weibull
vel_dia_aleat = wblinv(rand(10000,1), a_dia, b_dia);
vel_noche_aleat = wblinv(rand(10000,1), a_noche, b_noche);
    
% Dimensionamiento de la fuente eólica
Sn_FNCER = (Sn/FP); % capacidad nominal ajustada por factor de planta [MW]
n = round(Sn_FNCER/Sn_turbina); % número de turbinas necesarias

velocidad_curva = info_Turbina(:,1);
potencia_curva = info_Turbina(:,2);
    
% Identificación de velocidades características de la turbina desde la curva
% v_cut_in: velocidad mínima de arranque (potencia > 0)
idx_arranque = find(potencia_curva > 0, 1, 'first');
if idx_arranque > 1
    v_cut_in = velocidad_curva(idx_arranque - 1);
else
    v_cut_in = velocidad_curva(1);
end
    
% v_nominal: velocidad donde alcanza la potencia nominal
idx_nominal = find(potencia_curva >= 0.99 * Sn_turbina, 1, 'first');
if ~isempty(idx_nominal)
    v_nominal = velocidad_curva(idx_nominal);
else
    v_nominal = max(velocidad_curva);
end
    
% v_cut_out: última velocidad con potencia nominal o máximo de la curva
idx_after_nominal = find(potencia_curva >= 0.95 * Sn_turbina, 1, 'first');
if ~isempty(idx_after_nominal)
    % Buscar caída de potencia después de la zona nominal
    idx_cutout = find(potencia_curva(idx_after_nominal:end) < 0.01 * Sn_turbina, 1, 'first');
    if ~isempty(idx_cutout)
        % Hay un cut-out explícito en la curva
        v_cut_out = velocidad_curva(idx_after_nominal + idx_cutout - 2);
    else
        % No hay cut-out explícito, usar el máximo de la curva
        v_cut_out = max(velocidad_curva);
    end
else
    % Usar el máximo de la curva como fallback
    v_cut_out = max(velocidad_curva);
end
    
% Cálculo de potencia generada por una turbina durante el día
% Aplicación de la curva de potencia a las velocidades simuladas

potencia_dia_base = zeros(size(vel_dia_aleat));
   
for i = 1:length(vel_dia_aleat)
    v = vel_dia_aleat(i);
    
    if v < v_cut_in
        % Por debajo de velocidad de arranque
        potencia_dia_base(i) = 0;
        
    elseif v > v_cut_out
        % Por encima de velocidad de corte
        potencia_dia_base(i) = 0;
        
    elseif v >= v_cut_in && v <= v_nominal
        % Interpolación dentro del rango de la curva
        potencia_dia_base(i) = interp1(velocidad_curva, potencia_curva, v, 'linear');
        
    else % v_nominal < v <= v_cut_out
        % Mantiene potencia nominal
        potencia_dia_base(i) = Sn_turbina;
    end
end

% Incorporación de incertidumbre en la medición de potencia
% Factores de incertidumbre según rango de velocidad del viento
    
incertidumbre_dia = zeros(length(vel_dia_aleat),1);
for i = 1:length(incertidumbre_dia)
    if vel_dia_aleat(i) <= 5
        incertidumbre_dia(i) = 0.025/2;
    elseif vel_dia_aleat(i) > 5 && vel_dia_aleat(i) <= 9
        incertidumbre_dia(i) = 0.075/2;
    elseif vel_dia_aleat(i) > 9 && vel_dia_aleat(i) <= 11
        incertidumbre_dia(i) = 0.050/2;
    elseif vel_dia_aleat(i) > 11
        incertidumbre_dia(i) = 0.020/2;
    end
end

var_aleat_dia = ((2*rand(10000,1) - 1) .* incertidumbre_dia) .* potencia_dia_base;
p_dia = potencia_dia_base + var_aleat_dia;
p_dia = max(0, min(p_dia, Sn_turbina));
    
% Cálculo de potencia generada por una turbina durante la noche
% Aplicación de la curva de potencia a las velocidades simuladas
    
potencia_noche_base = zeros(size(vel_noche_aleat));
    
for i = 1:length(vel_noche_aleat)
    v = vel_noche_aleat(i);
    
    if v < v_cut_in
        % Por debajo de velocidad de arranque
        potencia_noche_base(i) = 0;
        
    elseif v > v_cut_out
        % Por encima de velocidad de corte
        potencia_noche_base(i) = 0;
        
    elseif v >= v_cut_in && v <= v_nominal
        % Interpolación dentro del rango de la curva
        potencia_noche_base(i) = interp1(velocidad_curva, potencia_curva, v, 'linear');
        
    else % v_nominal < v <= v_cut_out
        % Mantiene potencia nominal
        potencia_noche_base(i) = Sn_turbina;
    end
end

% Incorporación de incertidumbre en la medición de potencia
% Factores de incertidumbre según rango de velocidad del viento
     
incertidumbre_noche = zeros(length(vel_noche_aleat),1);
for i = 1:length(incertidumbre_noche)
    if vel_noche_aleat(i) <= 5
        incertidumbre_noche(i) = 0.025/2;
    elseif vel_noche_aleat(i) > 5 && vel_noche_aleat(i) <= 9
        incertidumbre_noche(i) = 0.075/2;
    elseif vel_noche_aleat(i) > 9 && vel_noche_aleat(i) <= 11
        incertidumbre_noche(i) = 0.050/2;
    elseif vel_noche_aleat(i) > 11
        incertidumbre_noche(i) = 0.020/2;
    end
end

var_aleat_noche = ((2*rand(10000,1) - 1) .* incertidumbre_noche) .* potencia_noche_base;
p_noche = potencia_noche_base + var_aleat_noche;
p_noche = max(0, min(p_noche, Sn_turbina));
    
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
    
% Estadísticos del período nocturno
m_noche = mean(p_noche); 
d_noche = std(p_noche); 
cv_noche = d_noche/m_noche;
media_noche = n*m_noche; % Media para la noche
des_noche = cv_noche*media_noche; % Desviacion para la noche
sesgo_noche = skewness(p_noche); % Sesgo para la noche
curtosis_noche = kurtosis(p_noche); % Curtosis para la noche
    
% Consolidación de resultados en tabla
Media   = [media_dia(:);   media_noche(:)];
DesvE   = [des_dia(:);     des_noche(:)];
Sesgo   = [sesgo_dia(:);   sesgo_noche(:)];
Curtosis= [curtosis_dia(:); curtosis_noche(:)];

Periodo = ["Día"; "Noche"];

MC_dia_noche = table(Periodo, Media, DesvE, Sesgo, Curtosis);
MC_dia_noche.Properties.VariableNames = ["Periodo", "Media","Desviación Estándar","Sesgo","Curtosis"];

end