clear
clc
tStart = tic;

%% SCRIPT: Proyecto 2 - Confiabilidad Nivel Jerárquico II (Generación + Transmisión)
% Caso Base: 100% Generación Síncrona

% ETAPA 1: SMC Nivel I (solo generación)
%   - Genera escenarios de fallas de generadores síncronos
%   - Clustering 3D (DNS + LoadRatio + K_gen)
%   - Guarda escenarios con su cluster asignado

% ETAPA 2: SMC Nivel II (generación + transmisión)
%   - Muestreo estratificado por clusters del Nivel I
%   - Genera fallas de líneas (K_total ≤ 2)
%   - Ejecuta OPF

%% PARÁMETROS CONFIGURABLES POR EL ESTUDIANTE
%  Modifique ÚNICAMENTE las variables de esta sección según el caso a evaluar.
%  No es necesario modificar ninguna otra parte del código.

% Demanda pico del sistema [MW]: 2850, 3075, 3300
p_max = 3300;

% Período de análisis: 1 = día, 0 = noche
dn = 1;

% Número de clusters: 0 = automático, o manual (3, 15, ...)
num_clusters = 0;

%% CONFIGURACIÓN GENERAL

% Realizaciones objetivo Nivel I
r_nivel1 = 500000;

% Error relativo máximo Nivel I
eps_nivel1 = 0.05;

% Realizaciones objetivo Nivel II
r_nivel2 = 50000;

sistema_prueba = 'case24_ieee_rts_1';

if num_clusters == 0
    k_str = 'auto';
else
    k_str = num2str(num_clusters);
end

%% ELEMENTOS CONVENCIONALES

% GENERADORES SÍNCRONOS

% Todos los generadores son síncronos (32 unidades)
gen_FNCER = ones(32, 1);

% Probabilidad de falla en estado estacionario (FOR) de cada generador
Pr_Falla_Gen = [0.1; 0.1; 0.02; 0.02; 0.1; 0.1; 0.02; 0.02; 0.04; 0.04; 0.04; ...
                0.05; 0.05; 0.05; 0.02; 0.02; 0.02; 0.02; 0.02; 0.04; 0.04; ...
                0.12; 0.12; 0.01; 0.01; 0.01; 0.01; 0.01; 0.01; 0.04; 0.04; 0.08];

% SISTEMA DE TRANSMISIÓN

% Tasa de falla λ de cada línea de transmisión [fallas/año]
lambda_LT = [0.24; 0.51; 0.33; 0.39; 0.48; 0.38; 0.02; 0.36; 0.34; 0.33; ...
             0.30; 0.44; 0.44; 0.02; 0.02; 0.02; 0.02; 0.40; 0.39; 0.40; ...
             0.52; 0.49; 0.38; 0.33; 0.41; 0.41; 0.41; 0.35; 0.34; 0.32; ...
             0.54; 0.35; 0.35; 0.38; 0.38; 0.34; 0.34; 0.45];

% Tiempo medio de reparación (MTTR) de cada línea [horas]
MTTR_LT = [16; 10; 10; 10; 10; 10; 768; 10; 10; 35; 10; 10; 10; 768; 768; ...
           768; 768; 11; 11; 11; 11; 11; 11; 11; 11; 11; 11; 11; 11; 11; ...
           11; 11; 11; 11; 11; 11; 11; 11];

% Tasa de reparación μ [reparaciones/año]
mu_LT = 8760 ./ MTTR_LT;

% Probabilidad de falla en estado estacionario de cada línea
Pr_Falla_LT = lambda_LT ./ (lambda_LT + mu_LT);

% Sin FNCER
typeFERNC = [];
Sn_FERNC = [];
CM = [];
VA = 1;
Co_FERNC = [];

%% SISTEMA DE GENERACIÓN

% Cargar caso para obtener capacidad de generación instalada
mpc = loadcase(sistema_prueba);

% Excluir condensador síncrono (Pmax = 0)
idx_gen_activos = mpc.gen(:, 9) > 0;
gen_activos = mpc.gen(idx_gen_activos, :);

% Calcular capacidades
Cap_sincrona = sum(gen_activos(:, 9));
Cap_total = Cap_sincrona;

% Calcular número de componentes
num_gen_sinc = sum(gen_FNCER == 1);
num_lineas = length(Pr_Falla_LT);

%% DEMANDA DEL SISTEMA

nombre_archivo = 'Carga.xlsx';
fp_original = 2850/sqrt(2850^2 + 580^2);
q_max = sqrt((p_max/fp_original)^2 - p_max^2);

% Distribución de carga por bus
porcentaje_carga = (1/100)*[3.8; 3.4; 6.3; 2.6; 2.5; 4.8; 4.4; 6.0; ...
                            6.1; 6.8; 0; 0; 9.3; 6.8; 11.1; 3.5; 0; ...
                            11.7; 6.4; 4.5; 0; 0; 0; 0];

[T_dia, T_noche, h_dia, h_noche] = Histograma_carga(nombre_archivo, p_max, q_max, 0);

if dn == 1
    LD = T_dia;
    periodo_str = 'DIA';
    h_period = h_dia;
else
    LD = T_noche;
    periodo_str = 'NOCHE';
    h_period = h_noche;
end

%% IMPRESIÓN EN CONSOLA: INFORMACIÓN DEL SISTEMA

fprintf('\nPROYECTO 2: CONFIABILIDAD NIVEL II (GENERACIÓN + TRANSMISIÓN)\n');
fprintf('CASO BASE: 100%% GENERACIÓN SÍNCRONA - %s\n\n', periodo_str);

fprintf('  Sistema:\n');
fprintf('    Generadores síncronos: %d\n', num_gen_sinc);
fprintf('    Líneas de transmisión: %d\n', num_lineas);
fprintf('    Capacidad total: %.1f MW\n', Cap_total);
fprintf('    Demanda pico: %.1f MW\n', p_max);
fprintf('    Margen de reserva: %.1f MW (%.1f%%)\n\n', ...
    Cap_total - p_max, (Cap_total - p_max)/p_max*100);

% Espacio de estados combinado Nivel II
estados_N2_gen = nchoosek(num_gen_sinc, 2);
estados_N2_lin = nchoosek(num_lineas, 2);
estados_N2_mix = num_gen_sinc * num_lineas;

total_N0 = 1;
total_N1 = num_gen_sinc + num_lineas;
total_N2 = estados_N2_gen + estados_N2_lin + estados_N2_mix;
total_estados = total_N0 + total_N1 + total_N2;

fprintf('  Espacio de estados (generación + transmisión):\n\n');
fprintf('    Truncamiento: K_gen + K_lin ≤ 2\n');
fprintf('      N-0: %d estado\n', total_N0);
fprintf('      N-1: %d estados (%d gen + %d lin)\n', total_N1, num_gen_sinc, num_lineas);
fprintf('      N-2: %d estados (%d gen-gen + %d lin-lin + %d gen-lin)\n', ...
    total_N2, estados_N2_gen, estados_N2_lin, estados_N2_mix);
fprintf('      Total: %d estados\n\n', total_estados);

fprintf('  Demanda:\n');
fprintf('    Estados de carga: %d\n', size(LD, 1));
fprintf('    Demanda pico: %.1f MW\n', p_max);
fprintf('    Período: %s\n\n', periodo_str);

%% EVALUACIÓN DE CONFIABILIDAD - NIVEL I

case_name_nivel1 = sprintf('N1_Base_%s_d%d_k%s', periodo_str, p_max, k_str);

[L_n1, E_DNS_n1, des_DNS_n1, LOLP_n1, error_DNS_n1, cont_mcs_n1, T_n1, ...
    T_escenarios, cluster_stats, TopK_Reps] = ...
    SMC_Nivel1_Clustering(sistema_prueba, gen_FNCER, Pr_Falla_Gen, ...
    typeFERNC, Sn_FERNC, CM, VA, Co_FERNC, ...
    r_nivel1, eps_nivel1, LD, dn, case_name_nivel1, num_clusters, h_period);

tiempo_nivel1 = toc(tStart);

%% EVALUACIÓN DE CONFIABILIDAD - NIVEL II

case_name_nivel2 = sprintf('N2_Base_%s_d%d_k%s', periodo_str, p_max, k_str);

[E_DNS_n2, des_DNS_n2, LOLP_n2, error_DNS_n2, cont_mcs_n2, T_resultados] = ...
    SMC_Nivel2_Muestreo(sistema_prueba, gen_FNCER, ...
    Pr_Falla_Gen, Pr_Falla_LT, typeFERNC, Sn_FERNC, CM, VA, Co_FERNC, ...
    r_nivel2, LD, dn, T_escenarios, cluster_stats, ...
    porcentaje_carga, case_name_nivel2, h_period, TopK_Reps);

tiempo_nivel2 = toc(tStart) - tiempo_nivel1;
tiempo_total = toc(tStart);

fprintf('\nTiempo Nivel I: %.2f min | Nivel II: %.2f min | Total: %.2f min\n', ...
    tiempo_nivel1/60, tiempo_nivel2/60, tiempo_total/60);