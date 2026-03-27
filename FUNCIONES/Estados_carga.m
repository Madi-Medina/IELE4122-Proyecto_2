function [sis_pru_histograma_carga, prob_sis_pru_histograma_carga] = Estados_carga(T, sistema_prueba, porcentaje_carga)
% Genera casos MATPOWER con diferentes niveles de demanda basados en el histograma probabilístico de carga

% Recibe:
%   T: tabla con histograma de carga discretizado. Type: table.
%      Columnas: Estado, Carga[%], Carga[MW], Carga[MVAr], Probabilidad, Acumulada
%   sistema_prueba: nombre del caso MATPOWER base. Type: string.
%   porcentaje_carga: vector de distribución porcentual de carga por bus. Type: vector (nx1) double.

% Retorna:
%   sis_pru_histograma_carga: cell array con casos MATPOWER, uno por estado de carga. Type: cell array.
%   prob_sis_pru_histograma_carga: probabilidades de cada estado. Type: cell array.


    % Cargar el sistema de prueba
    sis_pru = loadcase(sistema_prueba);   

    % Definir la cantidad de estados de la carga
    cant_estados = height(T);

    % Inicializar las matrices para almacenar la demanda de cada nodo para
    % estado del histograma de la carga
    sis_pru_bus_histograma_carga = cell(1, cant_estados);

    % Inicializar las matrices para almacenar la probabilidad de cada
    % estado del histograma
    prob_sis_pru_histograma_carga = cell(1, cant_estados);

    for i = 1:cant_estados

        prob_sis_pru_histograma_carga{i} = table2array(T(i,5));

    end
        
    for i = 1:cant_estados
    
        % Crear una copia de la matriz original con la información de los
        % nodos
        new_matrix = sis_pru.bus; 
    
        % Actualizar la demanda (P y Q) en cada nodo según el estado del
        % histograma para la carga
        new_matrix(:,3) = table2array(T(i,3))*porcentaje_carga; % P [MW]
        new_matrix(:,4) = table2array(T(i,4))*porcentaje_carga; % Q [MVAr]
    
        % Almacenar los resultados de la demanda de cada nodo para
        % estado del histograma de la carga
        sis_pru_bus_histograma_carga{i} = new_matrix;

    end

    % Calculo del flujo de potencia óptimo (función runopf del paquete Matpower)

    % Inicializar las celdas para almacenar el resultado del flujo de
    % potencia óptimo para cada estado del histograma de la carga
    % opf_histograma_carga = cell(1, cant_estados);

    % Inicializar las celdas para almacenar el casedata del sistema de prueba para cada estado del histograma de la carga    
    sis_pru_histograma_carga = cell(1, cant_estados);

    for i = 1:cant_estados

        % Crear una copia del sistema de prueba original con la información de los
        % nodos
        sis_pru_copia = sis_pru;

        % Actualizar la matriz con la información de la demanda (P y Q) en cada nodo según el estado del
        % histograma para la carga
        sis_pru_copia.bus = sis_pru_bus_histograma_carga{i};

        % Almacenar los casedata del sistema de prueba para cada estado del histograma de la carga
        sis_pru_histograma_carga{i} = sis_pru_copia; 
    end       

end