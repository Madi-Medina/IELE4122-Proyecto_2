function [T_dia,T_noche, h_dia, h_noche] = Histograma_carga(nombre_archivo,p_max,q_max,grafica)
% Genera histogramas probabilísticos de carga (P y Q) para períodos diurnos y nocturnos
% a partir de datos anuales de demanda

% Recibe:
%   nombre_archivo: archivo .xlsx con datos de demanda anual (8760x2)
%                   [hora_del_día, demanda_MW]. Type: string.
%   p_max: potencia activa máxima del sistema [MW]. Type: double.
%   q_max: potencia reactiva máxima del sistema [MVAr]. Type: double.
%   grafica: flag para generar gráficos (1=sí, 0=no). Type: double. 

% Retorna:
%   T_dia: tabla con histograma diurno (Estado, Carga[%], Carga[MW], 
%          Carga[MVAr], Probabilidad, Acumulada). Type: table.
%   T_noche: tabla con histograma nocturno (Estado, Carga[%], Carga[MW],
%            Carga[MVAr], Probabilidad, Acumulada). Type: table.
%   Nota: Si grafica=1, genera archivos Fig_dia.fig y Fig_noche.fig


    % Importación y normalización de datos de demanda
    datos = readmatrix(nombre_archivo);
    
    % Cálculo del factor de potencia del sistema
    fp = p_max / sqrt(p_max^2 + q_max^2);

    % Normalización de demanda [0-1]
    datos(:,2) = datos(:, 2) / max(datos(:, 2)); 
    
    % Clasificación de datos por estaciones del año
    % Invierno: Enero (744h) + Febrero (672h) + Diciembre (744h) = 2160h
    % Primavera: Marzo (744h) + Abril (720h) + Mayo (744h) = 2208h
    % Verano: Junio (720h) + Julio (744h) + Agosto (744h) = 2208h
    % Otoño: Septiembre (720h) + Octubre (744h) + Noviembre (720h) = 2184h
    invierno_data = [datos(1:1344,:); datos(7225:end,:) ]; % Datos de invierno
    primavera_data = datos(1345:2856,:); % Datos de primavera
    verano_data = datos(2857:5040,:); % Datos de verano
    otono_data = datos(5041:7224,:); % Datos de otoño

    % Separación de datos en períodos diurnos y nocturnos según estación
    % Los rangos horarios varían según la duración del día en cada estación
    
    % Invierno: día 7:00-17:00, noche 18:00-6:00
    dia_invierno = invierno_data(invierno_data(:,1) >= 7 & invierno_data(:,1) <= 17 , :); % Marcar las horas de día
    noche_invierno = invierno_data( invierno_data(:,1) <= 6 | invierno_data(:,1) > 17 , :);     % Marcar las horas de noche
    
    % Primavera: día 6:00-18:00, noche 19:00-5:00
    dia_primavera = primavera_data( primavera_data(:,1) >= 6 & primavera_data(:,1) < 19 , :); % Marcar las horas de día
    noche_primavera = primavera_data( primavera_data(:,1) <= 5 | primavera_data(:,1) >= 19 , :);     % Marcar las horas de noche
    
    % Otoño: día 7:00-18:00, noche 19:00-6:00
    dia_otono = otono_data( otono_data(:,1) >= 7 & otono_data(:,1) < 19 , :); % Marcar las horas de día
    noche_otono = otono_data( otono_data(:,1) <= 6 | otono_data(:,1) >= 19 , :);  % Marcar las horas de noche
    
    % Verano: día 6:00-20:00, noche 21:00-5:00
    dia_verano = verano_data( verano_data(:,1) >= 6 & verano_data(:,1) < 21 , :); % Marcar las horas de día
    noche_verano = verano_data( verano_data(:,1) <= 5 | verano_data(:,1) >= 21 , :);  % Marcar las horas de noche
    
    % Consolidación de datos diurnos y nocturnos
    datos_de_dia = [dia_invierno; dia_primavera; dia_otono; dia_verano];      % Datos del día
    datos_de_noche = [noche_invierno; noche_primavera; noche_otono; noche_verano];      % Datos de la noche
    
    % Construcción de histogramas mediante regla de Sturges
    cant_datos_dia = length(datos_de_dia(:,1));
    cant_datos_noche = length(datos_de_noche(:,1));
    
    % Número de clases según regla de Sturges: k = 1 + log2(n)
    num_clases_dia = ceil(1 + log2(cant_datos_dia));
    num_clases_noche = ceil(1 + log2(cant_datos_noche));
    
    % Inicialización de vectores para histogramas
    histogramas_marcas_dia = zeros(num_clases_dia,1);
    histogramas_marcas_noche = zeros(num_clases_noche,1);
    
    histogramas_frec_dia = zeros(num_clases_dia,1);
    histogramas_frec_noche = zeros(num_clases_noche,1);
    
    histogramas_frec_acu_noche = zeros(num_clases_dia,1);
    histogramas_frec_acu_dia = zeros(num_clases_noche,1);
    
    histogramas_proba_dia = zeros(num_clases_dia,1);
    histogramas_proba_noche = zeros(num_clases_noche,1);
    
    histogramas_proba_acu_dia = zeros(num_clases_dia,1);
    histogramas_proba_acu_noche = zeros(num_clases_noche,1);
    
    % Cálculo de intervalos de clase
    minimo_dia = min(datos_de_dia(:,2));
    maximo_dia = max(datos_de_dia(:,2));
    intervalo_dia = (maximo_dia - minimo_dia) / num_clases_dia;
    
    minimo_noche = min(datos_de_noche(:,2));
    maximo_noche = max(datos_de_noche(:,2));
    intervalo_noche = (maximo_noche - minimo_noche) / num_clases_noche;
    
    % Cálculo de marcas de clase (límite superior de cada intervalo)
    for j = 1:num_clases_dia
        if j == 1
            histogramas_marcas_dia(j,1) = minimo_dia + intervalo_dia;
        else
            histogramas_marcas_dia(j,1) = histogramas_marcas_dia(j-1,1) + intervalo_dia;
        end
    end
    
    for j = 1:num_clases_noche
        if j == 1
            histogramas_marcas_noche(j,1) = minimo_noche + intervalo_noche;
        else
            histogramas_marcas_noche(j,1) = histogramas_marcas_noche(j-1,1) + intervalo_noche;
        end
    end
    
    % Cálculo de frecuencias absolutas y acumuladas por clase
    for j = 1:num_clases_dia
        hora_prueba = datos_de_dia(:,2);
        if j == 1
            histogramas_frec_dia(j,1) = length(datos_de_dia( hora_prueba <= histogramas_marcas_dia(j,1), 2 ));   
            histogramas_frec_acu_dia(j,1) = histogramas_frec_dia(j,1);
        else
            histogramas_frec_dia(j,1) = length(datos_de_dia( hora_prueba <= histogramas_marcas_dia(j,1), 2 )) - sum(histogramas_frec_dia(1:j-1,1));
            histogramas_frec_acu_dia(j,1) = length(datos_de_dia( hora_prueba <= histogramas_marcas_dia(j,1), 2 ));
        end
    end
    
    for j = 1:num_clases_noche
        hora_prueba = datos_de_noche(:,2);
        if j == 1
            histogramas_frec_noche(j,1) = length(datos_de_noche( hora_prueba <= histogramas_marcas_noche(j,1), 2 ));   
            histogramas_frec_acu_noche(j,1) = histogramas_frec_noche(j,1);
        else
            histogramas_frec_noche(j,1) = length(datos_de_noche( hora_prueba <= histogramas_marcas_noche(j,1), 2 )) - sum(histogramas_frec_noche(1:j-1,1));
            histogramas_frec_acu_noche(j,1) = length(datos_de_noche( hora_prueba <= histogramas_marcas_noche(j,1), 2 ));
        end
    end
    
    % Cálculo de probabilidades y probabilidades acumuladas
    for j = 1:num_clases_dia                   
        histogramas_proba_dia(j,1) = histogramas_frec_dia(j,1) / sum(histogramas_frec_dia(:,1));
        histogramas_proba_acu_dia(j,1) = histogramas_frec_acu_dia(j,1) / sum(histogramas_frec_dia(:,1));
    end
    
    for j = 1:num_clases_noche                  
        histogramas_proba_noche(j,1) = histogramas_frec_noche(j,1) / sum(histogramas_frec_noche(:,1));
        histogramas_proba_acu_noche(j,1) = histogramas_frec_acu_noche(j,1) / sum(histogramas_frec_noche(:,1));
    end
    
    % Construcción de tabla de estados de carga diurnos    
    estado_dia = 1:1:num_clases_dia; % Estado de la carga
    carga_dia = histogramas_marcas_dia(:,1); % % de la carga 
    probabilidad_dia = histogramas_proba_dia(:,1); % Probabilidad de cada estado de carga
    acumulada_dia = histogramas_proba_acu_dia(:,1); % Probabilidad acumulada
    
    P_dia = carga_dia*p_max;
    Q_dia = P_dia * tan(acos(fp));
    T_dia = table(estado_dia', carga_dia, P_dia, Q_dia, probabilidad_dia, acumulada_dia);

    T_dia.Properties.VariableNames = ["Estado","Carga [%]","Carga [MW]","Carga [MVAr]","Probabilidad","Acumulada"];
    
    % Construcción de tabla de estados de carga nocturnos    
    estado_noche = 1:1:num_clases_noche; % Estado de la carga
    carga_noche = histogramas_marcas_noche(:,1); % % de la carga 
    probabilidad_noche = histogramas_proba_noche(:,1); % Probabilidad de cada estado de carga
    acumulada_noche = histogramas_proba_acu_noche(:,1); % Probabilidad acumulada
    
    P_noche = carga_noche*p_max;
    Q_noche = P_noche * tan(acos(fp));
    T_noche = table(estado_noche', carga_noche, P_noche, Q_noche, probabilidad_noche, acumulada_noche);

    T_noche.Properties.VariableNames = ["Estado","Carga [%]","Carga [MW]","Carga [MVAr]","Probabilidad","Acumulada"];
    
    % Cálculo de horas totales por período
    h_dia = length(datos_de_dia);
    h_noche = length(datos_de_noche);

    % Generación de gráficos (opcional)
    if grafica == 1
        % Histograma período diurno
        figure('Name', 'Histograma Demanda - Día');
        bar(probabilidad_dia*100, 0.8, 'FaceColor', [0.93 0.69 0.13], 'EdgeColor', 'k');
        set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%.2f', x), carga_dia*100, 'UniformOutput', false));
        xlabel('Carga [%]')
        ylabel('Frecuencia [%]')
        title('Histograma de la demanda - período diurno')
        legend('Probabilidad', 'Location', 'northeast')
        grid on
        box on
        
        % Histograma período nocturno
        figure('Name', 'Histograma Demanda - Noche');
        bar(probabilidad_noche*100, 0.8, 'FaceColor', [0 0.45 0.74], 'EdgeColor', 'k');
        set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%.2f', x), carga_noche*100, 'UniformOutput', false));
        xlabel('Carga [%]')
        ylabel('Frecuencia [%]')
        title('Histograma de la demanda - período nocturno')
        legend('Probabilidad', 'Location', 'northeast')
        grid on
        box on
    end

end