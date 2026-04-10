function[L, E_DNS, des_DNS, LOLP_day, error_DNS, cont_mcs, T, T_escenarios, cluster_stats, TopK_Reps] = SMC_Nivel1_Clustering(sistema_prueba, gen_FNCER, Pr_Falla_Gen, typeFERNC, Sn_FERNC, CM, VA, Co_FERNC, r, eps, LD, dn, case_name, num_clusters, h_period)
% Evalúa confiabilidad mediante Monte Carlo Nivel I (solo generación) con
% clustering 3D para identificar escenarios representativos

% Recibe:
%   sistema_prueba: nombre del caso MATPOWER. Type: string.
%   gen_FNCER: vector indicador (1=síncrono, 0=FNCER). Type: vector (nx1) double.
%   Pr_Falla_Gen: probabilidades de falla (FOR) de generadores. Type: vector (nx1) double.
%   typeFERNC: tipo de cada fuente renovable (1=eólica, 2=solar). Type: vector (mx1) double.
%   Sn_FERNC: capacidad nominal de cada fuente renovable [MW]. Type: vector (mx1) double.
%   CM: momentos centrales de las fuentes renovables. Type: matrix (4xm) double.
%   VA: tipo de variables aleatorias (1=independientes, 0=correlacionadas). Type: double.
%   Co_FERNC: matriz de correlación entre fuentes renovables. Type: matrix (mxm) double.
%   r: número de realizaciones objetivo. Type: double.
%   eps: error máximo permitido (0.05 = 5%). Type: double.
%   LD: tabla de estados de carga probabilísticos. Type: table.
%   dn: período (1=día, 0=noche). Type: double.
%   case_name: nombre para guardar resultados ('' = no guardar). Type: string.
%   num_clusters: número de clusters (0=automático, n>0=manual). Type: double.
%   h_period: horas del período en el año [horas]. Type: double.

% Retorna:
%   L: carga promedio esperada [MW]. Type: double.
%   E_DNS: esperanza de demanda no suministrada [MW]. Type: double.
%   des_DNS: desviación estándar de DNS [MW]. Type: double.
%   LOLP_day: probabilidad de pérdida de carga. Type: double.
%   error_DNS: error relativo alcanzado. Type: double.
%   cont_mcs: número de realizaciones completadas. Type: double.
%   T: tabla con evolución de la simulación. Type: table.
%   T_escenarios: tabla con escenarios únicos y clusters asignados. Type: table.
%   cluster_stats: estadísticas por cluster (centroides, frecuencias, medoides). Type: struct array.
%   TopK_Reps: TopK_Reps{c} es un struct array con los K escenarios más
%   frecuentes del cluster c. Type: cell array of struct (num_clusters x 1)

% METODOLOGÍA:
%   1. Simulación Monte Carlo con truncamiento K≤2
%   2. Identificación de escenarios únicos
%   3. Clustering K-means 3D: DNS + LoadRatio + K_gen
%   4. Selección automática de k (Max ASW + Min MSE)
%   5. Identificación de medoides representativos para Nivel II

% CARACTERÍSTICAS TÉCNICAS:
%   - Normalización Z-score en espacio 3D
%   - Caché global para reutilizar cálculos DNS
%   - Procesamiento paralelo por lotes
%   - Generación de números aleatorios anticipada
%   - Guardado automático de resultados y checkpoint

fprintf('SIMULACIÓN DE MONTECARLO NIVEL JERÁRQUICO I (SOLO GENERACIÓN) \n');
fprintf('\n');

% Validación de parámetros opcionales
if nargin < 14 || isempty(num_clusters)
    num_clusters = 0;  % 0 = selección automática de clusters
end

% Conversión si se recibe como string
if ischar(num_clusters) || isstring(num_clusters)
    if strcmpi(num_clusters, 'auto')
        num_clusters = 0;
    else
        num_clusters = str2double(num_clusters);
    end
end

% Verificación de caché de resultados previos
% Si existe un archivo con este case_name, carga resultados sin recalcular

if nargin >= 13 && ~isempty(case_name)
    filename = sprintf('%s.mat', case_name);
    
    if exist(filename, 'file')
        fprintf('  Resultados desde caché\n\n');
        data = load(filename);
        mc = data.mc_results;
        
        L = mc.L; 
        E_DNS = mc.E_DNS; 
        des_DNS = mc.std_DNS;
        LOLP_day = mc.LOLP; 
        error_DNS = mc.error;
        cont_mcs = mc.num_simulations; 
        T = mc.T;        
             
        if isfield(mc, 'T_escenarios')
            T_escenarios = mc.T_escenarios;
        else
            T_escenarios = table();
        end

        if isfield(mc, 'cluster_stats')
            cluster_stats = mc.cluster_stats;
        else
            cluster_stats = struct();
        end

        if isfield(mc, 'TopK_Reps')
            TopK_Reps = mc.TopK_Reps;
        else
            TopK_Reps = {};
        end
        
        % Calcular y mostrar espacio de estados
        sis_pru = loadcase(sistema_prueba);
        idx_gen_reales = find(sis_pru.gen(:, 9) > 0);
        idx_sync_en_vector = (gen_FNCER == 1);
        No_SYNC = sum(idx_sync_en_vector);
        
        estados_N0 = 1;
        estados_N1 = No_SYNC;
        estados_N2 = nchoosek(No_SYNC, 2);
        total_estados_gen = estados_N0 + estados_N1 + estados_N2;
        
        fprintf('  ESPACIO DE ESTADOS DE GENERACIÓN (NIVEL I)\n\n');
        fprintf('    Truncamiento: K ≤ 2 (máximo 2 generadores fallados)\n');
        fprintf('      N-0: %d estado\n', estados_N0);
        fprintf('      N-1: %d estados\n', estados_N1);
        fprintf('      N-2: %d estados\n', estados_N2);
        fprintf('      Total: %d estados\n\n', total_estados_gen);
        
        % Mostrar resultados completos
        fprintf('  RESULTADOS FINALES\n\n');
        
        fprintf('    Índices de confiabilidad:\n');
        fprintf('      E[DNS]: %.4f MW\n', E_DNS);
        fprintf('      σ[DNS]: %.4f MW\n', des_DNS);
        fprintf('      LOLP: %.6f (%.4f%%)\n', LOLP_day, LOLP_day*100);
        fprintf('      Error alcanzado: %.2f%%\n\n', error_DNS*100);
        
        fprintf('    Estadísticas de simulación:\n');
        fprintf('      Realizaciones válidas: %d\n', cont_mcs);
        if isfield(mc, 'rechazados')
            fprintf('      Casos rechazados (K>2): %d (%.1f%%)\n', ...
                mc.rechazados, mc.rechazados/(cont_mcs+mc.rechazados)*100);
        end
        if isfield(mc, 'execution_time_minutes')
            fprintf('      Tiempo: %.2f minutos\n', mc.execution_time_minutes);
            fprintf('      Velocidad: %.0f realizaciones/min\n\n', cont_mcs/mc.execution_time_minutes);
        end
        
        if isfield(mc, 'cache_stats')
            fprintf('    Caché:\n');
            fprintf('      Hit rate: %.1f%%\n', mc.cache_stats.hit_rate);
            fprintf('      Cálculos ejecutados: %d\n', mc.cache_stats.misses);
            fprintf('      Cálculos ahorrados: %d\n', mc.cache_stats.hits);
            fprintf('      Casos únicos: %d\n\n', mc.cache_stats.unique_cases);
        end
        
        if ~isempty(T_escenarios)
            fprintf('    RESUMEN DE ESCENARIOS Y CLUSTERING\n\n');
            fprintf('      Total escenarios únicos: %d\n', height(T_escenarios));
            fprintf('      Escenarios con DNS > 0: %d\n', sum(T_escenarios.DNS_MW > 0));
            
            if ismember('Cluster', T_escenarios.Properties.VariableNames) && isfield(mc, 'k_optimo_info')
                fprintf('      Método de clustering: %s\n', mc.k_optimo_info.variables);
                fprintf('      Método de selección: %s\n', mc.k_optimo_info.metodo);
                fprintf('      Número de clusters: %d\n', mc.k_optimo_info.k);
                fprintf('      ASW: %.4f\n', mc.k_optimo_info.ASW);
                fprintf('      MSE: %.6f\n\n', mc.k_optimo_info.MSE);
                
                % Mostrar tabla de estadísticas por cluster
                if isfield(mc, 'Medoides') && isfield(mc, 'cluster_stats')
                    k_final = mc.k_optimo_info.k;
                    Medoides = mc.Medoides;
                    cluster_stats = mc.cluster_stats;
                    
                    Cluster_ID = zeros(k_final, 1);
                    N_Escenarios = zeros(k_final, 1);
                    DNS_Medoide = zeros(k_final, 1);
                    LoadRatio_Medoide = zeros(k_final, 1);
                    K_gen_Medoide = zeros(k_final, 1);
                    Total_Repeticiones = zeros(k_final, 1);
                    Frecuencia_Pct = zeros(k_final, 1);
                    
                    for c = 1:k_final
                        Cluster_ID(c) = c;
                        N_Escenarios(c) = cluster_stats(c).num_escenarios;
                        DNS_Medoide(c) = Medoides(c).DNS_MW;
                        LoadRatio_Medoide(c) = Medoides(c).LoadRatio * 100;
                        K_gen_Medoide(c) = Medoides(c).K_gen;
                        Total_Repeticiones(c) = cluster_stats(c).total_repeticiones;
                        Frecuencia_Pct(c) = cluster_stats(c).freq_total * 100;
                    end
                    
                    T_Clusters = table(Cluster_ID, N_Escenarios, DNS_Medoide, LoadRatio_Medoide, K_gen_Medoide, ...
                                       Total_Repeticiones, Frecuencia_Pct);
                    T_Clusters.Properties.VariableNames = {'Cluster', 'Escenarios', 'DNS [MW]', ...
                                                           'Carga (% pico)', 'Gen. sinc. falla', 'Repeticiones', 'Freq(%)'};
                    
                    fprintf('      Estadísticas por cluster (caracterizados por medoide):\n\n');
                    disp(T_Clusters);
                    fprintf('\n');
                end
            end
        end
        
        fprintf('  Resultados cargados desde: %s\n\n', filename);
        
        return;
    end

    tic_start = tic;
else
    case_name = '';
    tic_start = tic;
end

% Inicialización del sistema de caché global
% Permite reutilizar cálculos DNS entre ejecuciones

cache_file = 'cache_montecarlo_gen.mat';
if exist(cache_file, 'file')
    fprintf('  Cargando caché global...\n');
    cache_data = load(cache_file);
    cache_global = cache_data.cache_dns;
    fprintf('    * %d casos en caché\n', length(cache_global.keys));
    
    % Conversión a struct para acceso rápido en workers paralelos
    cache_keys = keys(cache_global);
    cache_values = values(cache_global);
    cache_struct = struct();
    for i = 1:length(cache_keys)
        cache_struct.(['k_' strrep(cache_keys{i}, '-', '_')]) = cache_values{i};
    end
else
    fprintf('  Iniciando sin caché previo\n');
    cache_global = containers.Map('KeyType', 'char', 'ValueType', 'double');
    cache_struct = struct();
end

% Contadores de eficiencia de caché
total_hits = 0;
total_misses = 0;

% Tamaño de lote para procesamiento secuencial
batch_size = 5000;
fprintf('  Batch size: %d realizaciones\n', batch_size);

% Carga del sistema eléctrico y validación de datos
sis_pru = loadcase(sistema_prueba);
idx_gen_reales = find(sis_pru.gen(:, 9) > 0); % excluir condensador síncrono

% Validación de dimensiones de vectores de entrada
if length(gen_FNCER) ~= length(idx_gen_reales)
    error('gen_FNCER debe tener %d elementos', length(idx_gen_reales));
end

if length(Pr_Falla_Gen) ~= length(gen_FNCER)
    error('Pr_Falla_Gen debe tener %d elementos', length(gen_FNCER));
end

% Separación y caracterización de generadores síncronos
idx_sync_en_vector = (gen_FNCER == 1);
idx_sync_absolutos = idx_gen_reales(idx_sync_en_vector);

Sn_SYNC = sis_pru.gen(idx_sync_absolutos, 9)'; % capacidades [MW]
FOR_SYNC = Pr_Falla_Gen(idx_sync_en_vector)'; % probabilidades de falla
No_SYNC = length(Sn_SYNC);

% Cálculo del espacio de estados de generación con truncamiento K≤2
estados_N0 = 1;
estados_N1 = No_SYNC;
estados_N2 = nchoosek(No_SYNC, 2);
total_estados_gen = estados_N0 + estados_N1 + estados_N2;

fprintf('  \n');
fprintf('  ESPACIO DE ESTADOS DE GENERACIÓN (NIVEL I)\n\n');
fprintf('    Truncamiento: K ≤ 2 (máximo 2 generadores fallados)\n');
fprintf('      N-0: %d estado\n', estados_N0);
fprintf('      N-1: %d estados\n', estados_N1);
fprintf('      N-2: %d estados\n', estados_N2);
fprintf('      Total: %d estados\n', total_estados_gen);
fprintf('      \n');

% Preparación de datos de demanda probabilística
if istable(LD)
    Load_MW = table2array(LD(:, 3));
    Prob_Acum = table2array(LD(:, 6));
    num_estados_carga = length(Load_MW);
    usar_tabla = true;
    
    Prob_Individual = diff([0; Prob_Acum]);
    L = sum(Load_MW .* Prob_Individual);
    
elseif size(LD, 1) > 1 && size(LD, 2) >= 3
    Load_MW = LD(:, 1);
    Prob_Acum = LD(:, 3);
    num_estados_carga = length(Load_MW);
    usar_tabla = true;
    
    Prob_Individual = diff([0; Prob_Acum]);
    L = sum(Load_MW .* Prob_Individual);
else
    Load_MW = LD;
    num_estados_carga = 1;
    usar_tabla = false;
    L = Load_MW;
end

Ppeak = max(Load_MW); % potencia pico para cálculo de LoadRatio en clustering

% Cálculo de puntos de concentración para fuentes renovables
if ~isempty(typeFERNC)
    [p, w, pc] = PEM(typeFERNC, Sn_FERNC, CM, VA, Co_FERNC, dn);
    len = size(pc, 1);    
else
    len = 0;
    pc = [];
end

% Configuración de parámetros de simulación

fprintf('  CONFIGURACIÓN DE LA SIMULACIÓN\n\n');
fprintf('    Realizaciones objetivo: %d\n', r);
fprintf('    Error objetivo: %.1f%%\n', eps*100);
fprintf('    Modo: secuencial\n');

if num_clusters > 0
    fprintf('    Clustering: k=%d (manual)\n', num_clusters);
else
    fprintf('    Clustering: automático (Max ASW + Min MSE)\n');
end

% Inicialización de variables de simulación
cont_mcs = 0;
sum_DNS = 0;
sum_DNS2 = 0;
error_DNS = 1;
MCS = [];
rechazados = 0;
num_fallas_total = 0;

progress_interval = 10000;
save_interval = 50000;

% Mapa para escenarios únicos
escenarios_map = containers.Map('KeyType', 'char', 'ValueType', 'any');

fprintf('  \n');
fprintf('  INICIANDO SIMULACIÓN NIVEL I\n');
fprintf('  \n');

% Pre-generar números aleatorios
max_intentos = round(r * 1.2);
rand_carga = rand(max_intentos, 1);
rand_gen = rand(max_intentos, No_SYNC);
intento_actual = 0;

% Loop principal de simulación Monte Carlo con procesamiento paralelo por lotes

while cont_mcs < r && error_DNS >= eps
    
    % Construcción del lote de escenarios
    batch_data = [];
    batch_count = 0;
    
    while batch_count < batch_size && intento_actual < max_intentos && cont_mcs + batch_count < r
        intento_actual = intento_actual + 1;
        
        % Muestreo de estado de carga
        u_load = rand_carga(intento_actual);
        valores_gen = rand_gen(intento_actual, :)';
        
        if usar_tabla
            idx_carga = find(u_load <= Prob_Acum, 1);
            if isempty(idx_carga), idx_carga = num_estados_carga; end
            L_actual = Load_MW(idx_carga);
        else
            idx_carga = 1;
            L_actual = Load_MW;
        end
        
        % Muestreo de fallas de generadores
        gen_fallados = valores_gen <= FOR_SYNC';
        num_fallas = sum(gen_fallados);
        
        % Aplicación de truncamiento K≤2
        if num_fallas > 2
            rechazados = rechazados + 1;
            continue;
        end
        
        % Almacenar escenario válido en el lote
        batch_count = batch_count + 1;
        batch_data(batch_count).idx_carga = idx_carga;
        batch_data(batch_count).gen_fallados = gen_fallados;
        batch_data(batch_count).L_actual = L_actual;
        batch_data(batch_count).Sn_SYNC = Sn_SYNC;
    end
    
    if batch_count == 0
        rand_carga = rand(max_intentos, 1);
        rand_gen = rand(max_intentos, No_SYNC);
        intento_actual = 0;
        continue;
    end
    
    % Procesamiento secuencial del lote de escenarios
        
    batch_DNS = zeros(batch_count, 1);
    
    for b = 1:batch_count
        data = batch_data(b);
        
        % Construcción de clave única para caché
        gen_decimal = bi2de(data.gen_fallados');
        key_base = sprintf('D%d_%d_%d', dn, data.idx_carga, gen_decimal);
        
        % Cálculo de potencia síncrona disponible
        potencias_sync = data.Sn_SYNC .* ~data.gen_fallados';
        SUM_Pinj_SYNC = sum(potencias_sync);
        
        DNS_weighted = 0;
        
        % Cálculo de DNS según disponibilidad de fuentes renovables
        if len > 0
            % Sistema con FNCER: calcular DNS para cada punto PEM
            DNS_pem = zeros(len, 1);
            
            for k = 1:len
                key_pem = sprintf('%s_P%d', key_base, k);
                key_safe = ['k_' strrep(key_pem, '-', '_')];
                
                if isfield(cache_struct, key_safe)
                    DNS_pem(k) = cache_struct.(key_safe);
                    total_hits = total_hits + 1;
                else
                    total_misses = total_misses + 1;
                    P_FERNC_k = sum(pc(k, 2:(end-1)));
                    DNS_pem(k) = max(0, data.L_actual - SUM_Pinj_SYNC - P_FERNC_k);
                    cache_global(key_pem) = DNS_pem(k);
                    cache_struct.(key_safe) = DNS_pem(k);
                end
            end
            
            % DNS ponderado por pesos PEM
            DNS_weighted = sum(DNS_pem .* pc(:, end));
            
        else
            % Sistema sin FNCER: cálculo directo
            key_safe = ['k_' strrep(key_base, '-', '_')];
            
            if isfield(cache_struct, key_safe)
                DNS_weighted = cache_struct.(key_safe);
                total_hits = total_hits + 1;
            else
                total_misses = total_misses + 1;
                DNS_weighted = max(0, data.L_actual - SUM_Pinj_SYNC);
                cache_global(key_base) = DNS_weighted;
                cache_struct.(key_safe) = DNS_weighted;
            end
        end

        % Filtrar ruido numérico del PEM (consistente con Nivel 2 línea 480)
        if DNS_weighted < 0.01
            DNS_weighted = 0;
        end

        batch_DNS(b) = DNS_weighted;
    end
    
    % Acumulación de estadísticas y registro de escenarios
    for b = 1:batch_count
        cont_mcs = cont_mcs + 1;
        DNS_actual = batch_DNS(b);
        
        if DNS_actual > 0
            num_fallas_total = num_fallas_total + 1;
        end
        
        % Actualización de sumas para cálculo de momentos
        sum_DNS = sum_DNS + DNS_actual;
        sum_DNS2 = sum_DNS2 + DNS_actual^2;
        
        % Registro de escenario único en el mapa
        data = batch_data(b);
        gen_str = sprintf('%d', data.gen_fallados');
        escenario_key = sprintf('%d_%s', data.idx_carga, gen_str);
        
        if escenarios_map.isKey(escenario_key)
            info = escenarios_map(escenario_key);
            info(1) = info(1) + 1; % incrementar repeticiones
            escenarios_map(escenario_key) = info;
        else
            num_fallas_esc = sum(data.gen_fallados);
            escenarios_map(escenario_key) = [1, DNS_actual, data.L_actual, num_fallas_esc, data.idx_carga];
        end
        
        % Actualización de matriz de resultados
        if size(MCS, 1) < cont_mcs
            MCS(cont_mcs, :) = zeros(1, 5);
        end
        MCS(cont_mcs, 1) = cont_mcs;
        MCS(cont_mcs, 2) = DNS_actual;
        
        % Cálculo de estadísticas y error relativo
        if cont_mcs > 1
            mean_DNS = sum_DNS / cont_mcs;
            var_DNS = (sum_DNS2 - sum_DNS^2/cont_mcs) / (cont_mcs - 1);
            std_DNS = sqrt(max(0, var_DNS));
            se_DNS = std_DNS / sqrt(cont_mcs);
            
            % Error relativo con intervalo de confianza 95%
            if mean_DNS > 0
                error_DNS = (1.96 * se_DNS) / mean_DNS;
            else
                error_DNS = 1;
            end
            
            if isnan(error_DNS) || isinf(error_DNS)
                error_DNS = 1;
            end
            
            MCS(cont_mcs, 3) = mean_DNS;
            MCS(cont_mcs, 4) = std_DNS;
            MCS(cont_mcs, 5) = error_DNS;
        end
    end
     
    % Reporte de progreso periódico
    if mod(cont_mcs, progress_interval) == 0 || cont_mcs == 100
        tiempo_actual = toc(tic_start);
        hit_rate = total_hits / (total_hits + total_misses) * 100;
        vel = cont_mcs / (tiempo_actual/60);
        eta = (r - cont_mcs) / vel;
        
        fprintf('    Iter %6d: E[DNS]=%.4f MW, Error=%.2f%%, Hit=%.0f%%, Cache=%d, Vel=%.0f real/min, ETA=%.1f min\n', ...
                cont_mcs, mean_DNS, error_DNS*100, hit_rate, ...
                length(cache_global.keys), vel, eta);
    end
    
    % Guardado periódico de checkpoint
    if mod(cont_mcs, save_interval) == 0
        fprintf('      Guardando checkpoint (%d realizaciones)...\n', cont_mcs);
        cache_dns = cache_global;
        save(cache_file, 'cache_dns', '-v7.3');
    end
end

% Reporte final de la última iteración
fprintf('\n    Última iteración:\n');
fprintf('    Iter %6d: E[DNS]=%.4f MW, Error=%.2f%%, Hit=%.1f%%, Cache=%d\n', ...
        cont_mcs, mean_DNS, error_DNS*100, ...
        total_hits / (total_hits + total_misses) * 100, ...
        length(cache_global.keys));

% Cálculo de índices de confiabilidad finales
T = array2table(MCS(1:cont_mcs, :));
T.Properties.VariableNames = {'Realizacion', 'DNS', 'Mean_DNS', 'Std_DNS', 'Error'};

E_DNS = sum_DNS / cont_mcs;
des_DNS = sqrt(max(0, (sum_DNS2 - sum_DNS^2/cont_mcs) / (cont_mcs - 1)));

% Cálculo de LOLP según período
LOLP_day = (h_period/8760) * (num_fallas_total/cont_mcs);

error_DNS = MCS(cont_mcs, 5);

tiempo_total = toc(tic_start);
hit_rate_final = total_hits / (total_hits + total_misses) * 100;

% Construcción de tabla de escenarios únicos con sus estadísticas

escenario_keys = keys(escenarios_map);
num_escenarios = length(escenario_keys);

% Preasignación de arrays para eficiencia
Escenario_ID = cell(num_escenarios, 1);
Estado_Carga = zeros(num_escenarios, 1);
Carga_MW = zeros(num_escenarios, 1);
Num_Gen_Fallados = zeros(num_escenarios, 1);
Gen_Fallados_Vector = cell(num_escenarios, 1);
DNS_MW = zeros(num_escenarios, 1);
Repeticiones = zeros(num_escenarios, 1);
Frecuencia_Relativa = zeros(num_escenarios, 1);

% Extracción de información de cada escenario
for i = 1:num_escenarios
    key = escenario_keys{i};
    info = escenarios_map(key);
    
    Escenario_ID{i} = key;
    Repeticiones(i) = info(1);
    DNS_MW(i) = info(2);
    Carga_MW(i) = info(3);
    Num_Gen_Fallados(i) = info(4);
    Estado_Carga(i) = info(5);
    
    parts = strsplit(key, '_');
    if length(parts) >= 2
        gen_str = parts{2};
        gen_vector = zeros(1, length(gen_str));
        for j = 1:length(gen_str)
            gen_vector(j) = str2double(gen_str(j));
        end
        Gen_Fallados_Vector{i} = gen_vector;
    else
        Gen_Fallados_Vector{i} = [];
    end
    
    Frecuencia_Relativa(i) = Repeticiones(i) / cont_mcs;
end

% Cálculo de indicadores para clustering 3D: DNS + LoadRatio + K_gen

% LoadRatio: nivel de demanda normalizado respecto a la demanda pico
LoadRatio = Carga_MW / Ppeak;

% Clustering K-means 3D con normalización Z-score
% Variables: DNS (magnitud de falla) + LoadRatio (nivel de carga) + K_gen (número de fallas)

% Construcción de matriz de características
X = [DNS_MW, LoadRatio, Num_Gen_Fallados];

% Normalización Z-score para equiparar escalas
X_mean = mean(X);
X_std = std(X);
X_std(X_std == 0) = 1; % evitar división por cero
X_norm = (X - X_mean) ./ X_std;

% Determinación del número óptimo de clusters
if num_clusters <= 0

    k_range = 3:20;
    
    % Limitar por número de escenarios
    k_range = k_range(k_range <= num_escenarios);

    num_k = length(k_range);
    ASW_values = zeros(num_k, 1);
    MSE_values = zeros(num_k, 1);
    
    % Evaluar cada k
    for i = 1:num_k
        k = k_range(i);
        
        if k == 1
            ASW_values(i) = 0;
            MSE_values(i) = sum(var(X_norm));
        else
            % K-means con menos réplicas para velocidad
            [idx_temp, ~, sumd_temp] = kmeans(X_norm, k, 'Replicates', 5, ...
                'MaxIter', 500, 'Display', 'off');
            
            % ASW (Average Silhouette Width): calidad del clustering
            s = silhouette(X_norm, idx_temp);
            ASW_values(i) = mean(s);
            
            % MSE (Mean Squared Error): compacidad de los clusters
            MSE_values(i) = sum(sumd_temp) / num_escenarios;
        end
        
    end
    
    % Normalizar métricas a [0, 1]
    ASW_norm = (ASW_values - min(ASW_values)) / (max(ASW_values) - min(ASW_values) + 1e-10);
    MSE_norm = (max(MSE_values) - MSE_values) / (max(MSE_values) - min(MSE_values) + 1e-10);
    
    % Función objetivo: combinación ponderada de ASW y MSE
    w_ASW = 0.5;
    w_MSE = 0.5;
    Score = w_ASW * ASW_norm + w_MSE * MSE_norm;
    
    % Selección del k que maximiza el score combinado
    [max_score, idx_optimo] = max(Score);
    k_final = k_range(idx_optimo);
    
    % Guardar métricas de evaluación
    metricas_evaluacion = table(k_range', ASW_values, MSE_values, ASW_norm, MSE_norm, Score, ...
        'VariableNames', {'k', 'ASW', 'MSE', 'ASW_norm', 'MSE_norm', 'Score'});
    
    metodo_seleccion = 'automatico_ASW_MSE';
    
else
    % Modo manual: usar número de clusters especificado
    k_final = min(num_clusters, num_escenarios);    

    metodo_seleccion = 'manual';
    metricas_evaluacion = table();
end

% Ejecución de K-means con k óptimo (más réplicas para robustez)
rng(42);
[Cluster, centroids_norm, sumd] = kmeans(X_norm, k_final, ...
    'Replicates', 10, 'MaxIter', 1000, 'Display', 'off');

% Desnormalización de centroides al espacio original
centroids = centroids_norm .* X_std + X_mean;

% Cálculo de métricas finales del clustering
MSE_final = sum(sumd) / num_escenarios;
if k_final > 1
    ASW_final = mean(silhouette(X_norm, Cluster));
else
    ASW_final = NaN;
end

% Ordenamiento de clusters por severidad (DNS ascendente)
[~, orden] = sort(centroids(:,1));
mapa_cluster = zeros(k_final, 1);
for i = 1:k_final
    mapa_cluster(orden(i)) = i;
end
Cluster = mapa_cluster(Cluster);
centroids = centroids(orden, :);

% Asignación de nombres descriptivos a clusters
Cluster_Nombre = cell(num_escenarios, 1);
for i = 1:num_escenarios
    Cluster_Nombre{i} = sprintf('C%d', Cluster(i));
end

% Info para guardar
k_optimo_info = struct(...
    'metodo', metodo_seleccion, ...
    'variables', 'DNS + LoadRatio + K_gen (3D normalizado)', ...
    'k', k_final, ...
    'ASW', ASW_final, ...
    'MSE', MSE_final, ...
    'normalizacion', 'Z-score completo');

if strcmp(metodo_seleccion, 'automatico_ASW_MSE')
    k_optimo_info.metricas_evaluacion = metricas_evaluacion;
    k_optimo_info.rango_evaluado = [min(k_range), max(k_range)];
    k_optimo_info.pesos = struct('w_ASW', w_ASW, 'w_MSE', w_MSE);
end

% Construcción de tabla consolidada de escenarios
T_escenarios = table(Escenario_ID, Estado_Carga, Carga_MW, LoadRatio, ...
                     Num_Gen_Fallados, Gen_Fallados_Vector, DNS_MW, ...
                     Repeticiones, Frecuencia_Relativa, Cluster, Cluster_Nombre);

T_escenarios = sortrows(T_escenarios, {'Cluster', 'DNS_MW'}, {'ascend', 'descend'});

% Cálculo de estadísticas por cluster
cluster_stats = struct();
for c = 1:k_final
    mask = T_escenarios.Cluster == c;
    cluster_stats(c).cluster = c;
    cluster_stats(c).num_escenarios = sum(mask);
    cluster_stats(c).centroide_DNS = centroids(c, 1);
    cluster_stats(c).centroide_LoadRatio = centroids(c, 2);
    cluster_stats(c).centroide_Kgen = centroids(c, 3);
    cluster_stats(c).dns_min = min(T_escenarios.DNS_MW(mask));
    cluster_stats(c).dns_max = max(T_escenarios.DNS_MW(mask));
    cluster_stats(c).dns_mean = mean(T_escenarios.DNS_MW(mask));
    cluster_stats(c).std_DNS = std(T_escenarios.DNS_MW(mask));
    cluster_stats(c).total_repeticiones = sum(T_escenarios.Repeticiones(mask));
    cluster_stats(c).freq_total = sum(T_escenarios.Frecuencia_Relativa(mask));
end

% Identificación de medoides: escenarios representativos para Nivel II
% El medoide es el escenario más cercano al centroide de cada cluster

Medoides = struct();
for c = 1:k_final
    mask = find(T_escenarios.Cluster == c);
    
    % Extraer características del cluster en espacio 3D
    X_cluster = [T_escenarios.DNS_MW(mask), T_escenarios.LoadRatio(mask), T_escenarios.Num_Gen_Fallados(mask)];
    
    % Normalización para cálculo de distancias
    X_cluster_norm = (X_cluster - X_mean) ./ X_std;
    centroid_norm = (centroids(c,:) - X_mean) ./ X_std;
    
    % Distancia euclidiana al centroide
    dist_to_centroid = sqrt(sum((X_cluster_norm - centroid_norm).^2, 2));
    
    % Selección del escenario más cercano (medoide)
    [~, idx_medoide] = min(dist_to_centroid);
    idx_global = mask(idx_medoide);
    
    % Cálculo de K_lin_max para Nivel II (restricción K_total ≤ 2)
    K_gen_medoide = T_escenarios.Num_Gen_Fallados(idx_global);
    K_lin_max_medoide = 2 - K_gen_medoide;  % K_total <= 2
    
     % Almacenamiento de propiedades del medoide
    Medoides(c).cluster = c;
    Medoides(c).escenario_id = T_escenarios.Escenario_ID{idx_global};
    Medoides(c).idx_tabla = idx_global;
    Medoides(c).DNS_MW = T_escenarios.DNS_MW(idx_global);
    Medoides(c).LoadRatio = T_escenarios.LoadRatio(idx_global);
    Medoides(c).Carga_MW = T_escenarios.Carga_MW(idx_global);
    Medoides(c).Num_Gen_Fallados = K_gen_medoide;
    Medoides(c).Gen_Fallados_Vector = T_escenarios.Gen_Fallados_Vector{idx_global};
    Medoides(c).peso = cluster_stats(c).freq_total;
    Medoides(c).K_gen = K_gen_medoide;
    Medoides(c).K_lin_max = K_lin_max_medoide;
end

% Selección de Top-K representantes por cluster
% K automático: min(ceil(sqrt(n_escenarios)), K_MAX)
% Captura diversidad intra-cluster para mejor estimación con FNCER

K_MAX = 3;
TopK_Reps = cell(k_final, 1);

for c = 1:k_final
    mask_c = find(T_escenarios.Cluster == c);
    n_esc = length(mask_c);
    
    % K automático según tamaño del cluster
    K = min(ceil(sqrt(n_esc)), K_MAX);
    K = min(K, n_esc);
    
    % Ordenar por repeticiones descendente
    rep_c = T_escenarios.Repeticiones(mask_c);
    [rep_sorted, idx_sort] = sort(rep_c, 'descend');
    
    % Seleccionar Top-K
    idx_topK = mask_c(idx_sort(1:K));
    rep_topK = rep_sorted(1:K);
    pesos_internos = rep_topK / sum(rep_topK);
    cobertura = sum(rep_topK) / sum(rep_c) * 100;
    
    % Construir struct array de representantes
    reps = struct();
    for r = 1:K
        ig = idx_topK(r);
        reps(r).idx_global = ig;
        reps(r).escenario_id = T_escenarios.Escenario_ID{ig};
        reps(r).estado_carga = T_escenarios.Estado_Carga(ig);
        reps(r).gen_fallados = T_escenarios.Gen_Fallados_Vector{ig};
        reps(r).K_gen = T_escenarios.Num_Gen_Fallados(ig);
        reps(r).K_lin_max = 2 - reps(r).K_gen;
        reps(r).DNS_MW = T_escenarios.DNS_MW(ig);
        reps(r).repeticiones = rep_topK(r);
        reps(r).peso = pesos_internos(r);
    end
    
    TopK_Reps{c} = reps;
    
end

% Impresión de resultados finales

fprintf('  \n');
fprintf('  RESULTADOS FINALES\n\n');

fprintf('    Índices de confiabilidad:\n');
fprintf('      E[DNS]: %.4f MW\n', E_DNS);
fprintf('      σ[DNS]: %.4f MW\n', des_DNS);
fprintf('      LOLP: %.6f (%.4f%%)\n', LOLP_day, LOLP_day*100);
fprintf('      Error alcanzado: %.2f%%\n\n', error_DNS*100);

fprintf('    Estadísticas de simulación:\n');
fprintf('      Realizaciones válidas: %d\n', cont_mcs);
fprintf('      Casos rechazados (K>2): %d (%.1f%%)\n', rechazados, rechazados/(cont_mcs+rechazados)*100);
fprintf('      Tiempo: %.2f minutos\n', tiempo_total/60);
fprintf('      Velocidad: %.0f realizaciones/min\n\n', cont_mcs/(tiempo_total/60));

fprintf('    Caché:\n');
fprintf('      Hit rate: %.1f%%\n', hit_rate_final);
fprintf('      Cálculos ejecutados: %d\n', total_misses);
fprintf('      Cálculos ahorrados: %d\n', total_hits);
fprintf('      Casos únicos: %d\n\n', length(cache_global.keys));


fprintf('  RESUMEN DE ESCENARIOS Y CLUSTERING\n\n');
fprintf('    Total escenarios únicos: %d\n', num_escenarios);
fprintf('    Escenarios con DNS > 0: %d\n', sum(DNS_MW > 0));
fprintf('    Método de clustering: 3D (DNS + LoadRatio + K_gen)\n');
fprintf('    Método de selección: %s\n', metodo_seleccion);
fprintf('    Número de clusters: %d\n', k_final);
fprintf('    ASW: %.4f\n', ASW_final);
fprintf('    MSE: %.6f\n\n', MSE_final);

% Construcción de tabla de estadísticas por cluster usando medoides
Cluster_ID = zeros(k_final, 1);
N_Escenarios = zeros(k_final, 1);
DNS_Medoide = zeros(k_final, 1);
LoadRatio_Medoide = zeros(k_final, 1);
K_gen_Medoide = zeros(k_final, 1);
Total_Repeticiones = zeros(k_final, 1);
Frecuencia_Pct = zeros(k_final, 1);

for c = 1:k_final
    Cluster_ID(c) = c;
    N_Escenarios(c) = cluster_stats(c).num_escenarios;
    DNS_Medoide(c) = Medoides(c).DNS_MW;
    LoadRatio_Medoide(c) = Medoides(c).LoadRatio * 100;  % convertir a porcentaje
    K_gen_Medoide(c) = Medoides(c).K_gen;
    Total_Repeticiones(c) = cluster_stats(c).total_repeticiones;
    Frecuencia_Pct(c) = cluster_stats(c).freq_total * 100;
end

T_Clusters = table(Cluster_ID, N_Escenarios, DNS_Medoide, LoadRatio_Medoide, K_gen_Medoide, ...
                   Total_Repeticiones, Frecuencia_Pct);
T_Clusters.Properties.VariableNames = {'Cluster', 'Escenarios', 'DNS [MW]', ...
                                       'Carga (% pico)', 'Gen. sinc. falla', 'Repeticiones', 'Freq(%)'};

fprintf('    Estadísticas por cluster (caracterizados por medoide):\n\n');
disp(T_Clusters);
fprintf('\n');

% Guardado de resultados en archivo .mat

if ~isempty(case_name)
    mc_results = struct('case_name', case_name, 'L', L, 'E_DNS', E_DNS, ...
        'std_DNS', des_DNS, 'LOLP', LOLP_day, 'error', error_DNS, ...
        'num_simulations', cont_mcs, 'num_fallas', num_fallas_total, ...
        'rechazados', rechazados, 'T', T, ...
        'T_escenarios', T_escenarios, ...
        'num_escenarios_unicos', num_escenarios, ...
        'num_clusters', k_final, ...
        'cluster_centroids', centroids, ...
        'cluster_stats', cluster_stats, ...
        'Medoides', Medoides, ...
        'TopK_Reps', {TopK_Reps}, ...
        'k_optimo_info', k_optimo_info, ...
        'Ppeak', Ppeak, ...
        'cache_stats', struct('hits', total_hits, 'misses', total_misses, ...
            'hit_rate', hit_rate_final, 'unique_cases', length(cache_global.keys)), ...
        'execution_time_minutes', tiempo_total/60, 'timestamp', datestr(now));
    
    filename = sprintf('%s.mat', case_name);
    save(filename, 'mc_results', '-v7.3');
    
    % Actualización del caché global
    cache_dns = cache_global;
    save(cache_file, 'cache_dns', '-v7.3');
    
    fprintf('  Resultados guardados: %s\n', filename);
    fprintf('  Caché actualizado: %s (%d entradas)\n\n', cache_file, length(cache_dns.keys));
end

end