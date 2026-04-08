clear
clc
tStart = tic;

%% SCRIPT: Proyecto 2 - Confiabilidad Nivel Jerárquico II (Generación + Transmisión)
% Caso Solar: 23 generadores síncronos + 9 parques solares

% ETAPA 1: SMC Nivel I (solo generación)
%   - Genera escenarios de fallas de generadores síncronos
%   - Clustering 3D (DNS + LoadRatio + K_gen)
%   - Guarda escenarios con su cluster asignado

% ETAPA 2: SMC Nivel II (generación + transmisión)
%   - Muestreo estratificado por clusters del Nivel I
%   - Genera fallas de líneas (K_total ≤ 2)
%   - Ejecuta OPF con PEM para FNCER

%% PARÁMETROS CONFIGURABLES POR EL ESTUDIANTE
%  Modifique ÚNICAMENTE las variables de esta sección según el caso a evaluar.
%  No es necesario modificar ninguna otra parte del código.

% Demanda pico del sistema [MW]: 2850, 3075, 3300
p_max = 3300;

% Período de análisis: 1 = día (solar solo genera de día)
dn = 1;

% Número de clusters: 0 = automático, o manual (3, 15, ...)
num_clusters = 0;

%% CONFIGURACIÓN GENERAL

% Realizaciones objetivo Nivel I
r_nivel1 = 500000;

% Error relativo máximo Nivel I
eps_nivel1 = 0.05;

% Realizaciones objetivo Nivel II
r_nivel2 = 20000;

% Multiplicador de capacidad renovable: 1, 2, 3, ...
factor_cap = 1;

sistema_prueba = 'case24_ieee_rts_1';

if num_clusters == 0
    k_str = 'auto';
else
    k_str = num2str(num_clusters);
end

%% ELEMENTOS CONVENCIONALES

% gen_FNCER: 1 = síncrono, 0 = FNCER (solar)
% 32 generadores total: 23 síncronos + 9 solares
gen_FNCER = [1; 1; 0; 0; 1; 1; 0; 0; 1; 1; 1; 1; 1; 1; 1; 1; 1; 1; 1; 0; 0; 1; 1; 1; 1; 1; 1; 1; 1; 0; 0; 0];

% FOR de cada generador (32 elementos, incluye posiciones reemplazadas)
Pr_Falla_Gen = [0.1; 0.1; 0.02; 0.02; 0.1; 0.1; 0.02; 0.02; 0.04; 0.04; 0.04; ...
                0.05; 0.05; 0.05; 0.02; 0.02; 0.02; 0.02; 0.02; 0.04; 0.04; ...
                0.12; 0.12; 0.01; 0.01; 0.01; 0.01; 0.01; 0.01; 0.04; 0.04; 0.08];

% SISTEMA DE TRANSMISIÓN

lambda_LT = [0.24; 0.51; 0.33; 0.39; 0.48; 0.38; 0.02; 0.36; 0.34; 0.33; ...
             0.30; 0.44; 0.44; 0.02; 0.02; 0.02; 0.02; 0.40; 0.39; 0.40; ...
             0.52; 0.49; 0.38; 0.33; 0.41; 0.41; 0.41; 0.35; 0.34; 0.32; ...
             0.54; 0.35; 0.35; 0.38; 0.38; 0.34; 0.34; 0.45];

MTTR_LT = [16; 10; 10; 10; 10; 10; 768; 10; 10; 35; 10; 10; 10; 768; 768; ...
           768; 768; 11; 11; 11; 11; 11; 11; 11; 11; 11; 11; 11; 11; 11; ...
           11; 11; 11; 11; 11; 11; 11; 11];

mu_LT = 8760 ./ MTTR_LT;
Pr_Falla_LT = lambda_LT ./ (lambda_LT + mu_LT);

%% FUENTES RENOVABLES NO CONVENCIONALES (FNCER)

% Capacidad síncrona removida [MW] por cada parque
% Parques 1-4: 76 MW (Bus 1 y 2, zona Norte)
% Parques 5-9: 155/350 MW (Buses 15, 16, 23, zona Sur)
Sn = [76 76 76 76 155 155 155 155 350];

% Datos de irradiancia solar (archivo CSV con columnas: año, mes, día, hora, minuto, GHI)
data_solar = 'Solar.csv';

% Celda solar
Sn_celda = 1.25; % Capacidad nominal [MW]

% Factores de planta
FP_norte = 0.55;
FP_sur = 0.50;

% Caracterización estadística (factor_cap escala la capacidad renovable)
[MC1, Sn_FNCER1, a_dia_n, b_dia_n] = Generacion_solar(data_solar, Sn(1)*factor_cap, Sn_celda, FP_norte);
[MC2, Sn_FNCER2]                    = Generacion_solar(data_solar, Sn(2)*factor_cap, Sn_celda, FP_norte);
[MC3, Sn_FNCER3]                    = Generacion_solar(data_solar, Sn(3)*factor_cap, Sn_celda, FP_norte);
[MC4, Sn_FNCER4]                    = Generacion_solar(data_solar, Sn(4)*factor_cap, Sn_celda, FP_norte);
[MC5, Sn_FNCER5, a_dia_s, b_dia_s] = Generacion_solar(data_solar, Sn(5)*factor_cap, Sn_celda, FP_sur);
[MC6, Sn_FNCER6]                    = Generacion_solar(data_solar, Sn(6)*factor_cap, Sn_celda, FP_sur);
[MC7, Sn_FNCER7]                    = Generacion_solar(data_solar, Sn(7)*factor_cap, Sn_celda, FP_sur);
[MC8, Sn_FNCER8]                    = Generacion_solar(data_solar, Sn(8)*factor_cap, Sn_celda, FP_sur);
[MC9, Sn_FNCER9]                    = Generacion_solar(data_solar, Sn(9)*factor_cap, Sn_celda, FP_sur);

% Configuración PEM
typeFERNC = [2 2 2 2 2 2 2 2 2];
Sn_FERNC = [Sn_FNCER1 Sn_FNCER2 Sn_FNCER3 Sn_FNCER4 Sn_FNCER5 Sn_FNCER6 Sn_FNCER7 Sn_FNCER8 Sn_FNCER9];

% Momentos centrales según período
idx_periodo = 2 - dn;
CM = [double(table2array(MC1(idx_periodo,2:end)))' double(table2array(MC2(idx_periodo,2:end)))' ...
      double(table2array(MC3(idx_periodo,2:end)))' double(table2array(MC4(idx_periodo,2:end)))' ...
      double(table2array(MC5(idx_periodo,2:end)))' double(table2array(MC6(idx_periodo,2:end)))' ...
      double(table2array(MC7(idx_periodo,2:end)))' double(table2array(MC8(idx_periodo,2:end)))' ...
      double(table2array(MC9(idx_periodo,2:end)))']; 

VA = 1;
Co_FERNC = [1    0.75 0.75 0.75 0.75 0.75 0.75 0.75 0.75;
            0.75 1    0.75 0.75 0.75 0.75 0.75 0.75 0.75;
            0.75 0.75 1    0.75 0.75 0.75 0.75 0.75 0.75;
            0.75 0.75 0.75 1    0.75 0.75 0.75 0.75 0.75;
            0.75 0.75 0.75 0.75 1    0.75 0.75 0.75 0.75; 
            0.75 0.75 0.75 0.75 0.75 1    0.75 0.75 0.75;
            0.75 0.75 0.75 0.75 0.75 0.75 1    0.75 0.75;
            0.75 0.75 0.75 0.75 0.75 0.75 0.75 1    0.75;
            0.75 0.75 0.75 0.75 0.75 0.75 0.75 0.75 1   ];

%% SISTEMA DE GENERACIÓN

mpc = loadcase(sistema_prueba);
idx_gen_activos = mpc.gen(:, 9) > 0;
gen_activos = mpc.gen(idx_gen_activos, :);

Cap_sincrona = sum(gen_activos(gen_FNCER == 1, 9));
Cap_sinc_removida = sum(Sn);
Cap_renovable = sum(Sn_FERNC);
Cap_total = Cap_sincrona + Cap_renovable;

num_gen_sinc = sum(gen_FNCER == 1);
num_lineas = length(Pr_Falla_LT);

%% DEMANDA DEL SISTEMA

nombre_archivo = 'Carga.xlsx';
fp_original = 2850/sqrt(2850^2 + 580^2);
q_max = sqrt((p_max/fp_original)^2 - p_max^2);

porcentaje_carga = (1/100)*[3.8; 3.4; 6.3; 2.6; 2.5; 4.8; 4.4; 6.0; ...
                            6.1; 6.8; 0; 0; 9.3; 6.8; 11.1; 3.5; 0; ...
                            11.7; 6.4; 4.5; 0; 0; 0; 0];

[T_dia, T_noche, h_dia, h_noche] = Histograma_carga(nombre_archivo, p_max, q_max, 0);

if dn == 1
    LD = T_dia;  periodo_str = 'DIA';  h_period = h_dia;
else
    LD = T_noche; periodo_str = 'NOCHE'; h_period = h_noche;
end

%% IMPRESIÓN EN CONSOLA

fprintf('\nPROYECTO 2: CONFIABILIDAD NIVEL II (GENERACIÓN + TRANSMISIÓN)\n');
fprintf('CASO SOLAR - %s (factor_cap = %d)\n\n', periodo_str, factor_cap);

fprintf('  Sistema:\n');
fprintf('    Generadores: %d síncronos + %d solares\n', num_gen_sinc, sum(gen_FNCER == 0));
fprintf('    Líneas de transmisión: %d\n', num_lineas);
fprintf('    Capacidad síncrona: %.1f MW\n', Cap_sincrona);
fprintf('    Capacidad síncrona removida: %.1f MW\n', Cap_sinc_removida);
fprintf('    Capacidad renovable instalada: %.1f MW (factor_cap = %d)\n', Cap_renovable, factor_cap);
fprintf('    Capacidad total: %.1f MW\n', Cap_total);
fprintf('    Demanda pico: %.1f MW\n\n', p_max);

% Espacio de estados
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

%% EVALUACIÓN DE CONFIABILIDAD - NIVEL I

case_name_nivel1 = sprintf('N1_Solar_%s_d%d_f%d_k%s', periodo_str, p_max, factor_cap, k_str);

[L_n1, E_DNS_n1, des_DNS_n1, LOLP_n1, error_DNS_n1, cont_mcs_n1, T_n1, ...
    T_escenarios, cluster_stats, TopK_Reps] = ...
    SMC_Nivel1_Clustering(sistema_prueba, gen_FNCER, Pr_Falla_Gen, ...
    typeFERNC, Sn_FERNC, CM, VA, Co_FERNC, ...
    r_nivel1, eps_nivel1, LD, dn, case_name_nivel1, num_clusters, h_period);

tiempo_nivel1 = toc(tStart);

%% EVALUACIÓN DE CONFIABILIDAD - NIVEL II

case_name_nivel2 = sprintf('N2_Solar_%s_d%d_f%d_k%s', periodo_str, p_max, factor_cap, k_str);

[E_DNS_n2, des_DNS_n2, LOLP_n2, cont_mcs_n2, T_resultados] = ...
    SMC_Nivel2_Muestreo(sistema_prueba, gen_FNCER, ...
    Pr_Falla_Gen, Pr_Falla_LT, typeFERNC, Sn_FERNC, CM, VA, Co_FERNC, ...
    r_nivel2, LD, dn, T_escenarios, cluster_stats, ...
    porcentaje_carga, case_name_nivel2, h_period, TopK_Reps);

tiempo_nivel2 = toc(tStart) - tiempo_nivel1;
tiempo_total = toc(tStart);

%% RESUMEN

fprintf('\nRESUMEN DEL SCRIPT\n');
fprintf('  Nivel I:  E[DNS] = %.4f MW, Error = %.2f%%\n', E_DNS_n1, error_DNS_n1*100);
fprintf('  Nivel II: E[DNS] = %.4f MW\n', E_DNS_n2);
fprintf('  Tiempos:  Nivel I = %.2f min | Nivel II = %.2f min | Total = %.2f min\n', ...
    tiempo_nivel1/60, tiempo_nivel2/60, tiempo_total/60);