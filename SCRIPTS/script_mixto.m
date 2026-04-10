clear
clc
tStart = tic;

%% SCRIPT: Proyecto 2 - Confiabilidad Nivel Jerárquico II (Generación + Transmisión)
% Caso Mixto: 23 generadores síncronos + parques eólicos y solares

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

% Demanda pico del sistema [MW]: 3300
p_max = 3300;

% Período de análisis: 1 = día; 0 = noche
dn = 1;

% Configuración de tecnologías: 1, 2 o 3
%   1: Eólica Norte + Solar Sur  
%   2: Solar Norte + Eólica Sur  
%   3: Mixta en ambas zonas      
config = 1;

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

% Selección de configuración tecnológica
% config_tech: 1 = eólica, 2 = solar (por parque)
% Parques 1-4: Buses 1-2 (zona Norte)
% Parques 5-9: Buses 15, 16, 23 (zona Sur)
switch config
    case 1
        config_tech = [1 1 1 1 2 2 2 2 2];
        config_name = 'EolNorte_SolSur';
    case 2
        config_tech = [2 2 2 2 1 1 1 1 1];
        config_name = 'SolNorte_EolSur';
    case 3
        config_tech = [1 2 1 2 1 2 1 2 1];
        config_name = 'Intercalada';
    otherwise
        error('Configuración no válida. Use 1, 2 o 3.');
end

%% ELEMENTOS CONVENCIONALES

% gen_FNCER: 1 = síncrono, 0 = FNCER
% 32 generadores total: 23 síncronos + 9 renovables
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

% Zona geográfica: 1 = Norte, 2 = Sur
zona = [1 1 1 1 2 2 2 2 2];

% Parámetros eólicos
data_eolica_norte = [12 1.85 12 1.85];
data_eolica_sur = [10 1.75 10 1.75];
Sn_turbina = 2.750;
c1 = 1:1:30;
c2 = 1/1000.*[0 0 0 17.8 118.4 257.8 447.3 693.2 997.7 1345 1708 2055.4 ...
              2349.8 2554.2 2667.4 2718.5 2738.2 2745.1 2747.3 2750 2750 ...
              2750 2750 2750 2750 0 0 0 0 0];
info_Turbina = [c1' c2'];
FP_eolica_norte = 0.48;
FP_eolica_sur = 0.39;

% Parámetros solares
data_solar = 'Solar.csv';
Sn_celda = 1.25;
FP_solar_norte = 0.55;
FP_solar_sur = 0.50;

% Caracterización estadística según config_tech y zona
MC_cell = cell(1, 9);
Sn_FNCER_vec = zeros(1, 9);

for i = 1:9
    if zona(i) == 1
        data_eol = data_eolica_norte;
        fp_eol = FP_eolica_norte;
        fp_sol = FP_solar_norte;
    else
        data_eol = data_eolica_sur;
        fp_eol = FP_eolica_sur;
        fp_sol = FP_solar_sur;
    end
    
    if config_tech(i) == 1  % Eólica
        [MC_cell{i}, Sn_FNCER_vec(i)] = Generacion_eolica(data_eol, Sn(i)*factor_cap, Sn_turbina, info_Turbina, fp_eol);
    else  % Solar
        [MC_cell{i}, Sn_FNCER_vec(i)] = Generacion_solar(data_solar, Sn(i)*factor_cap, Sn_celda, fp_sol);
    end
end

% Configuración PEM
typeFERNC = config_tech;
Sn_FERNC = Sn_FNCER_vec;

% Momentos centrales según período
idx_periodo = 2 - dn;
CM = zeros(4, 9);
for i = 1:9
    CM(:, i) = double(table2array(MC_cell{i}(idx_periodo, 2:end)))';
end

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
num_eolicos = sum(config_tech == 1);
num_solares = sum(config_tech == 2);
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
fprintf('CASO MIXTO - %s (factor_cap = %d, config = %d)\n', periodo_str, factor_cap, config);
fprintf('Configuración: %s\n\n', config_name);

fprintf('  Distribución de tecnologías:\n');
tech_names = {'Eólica', 'Solar'};
zona_names = {'Norte', 'Sur'};
for i = 1:9
    fprintf('    Parque %d: %s (%s) - %.0f MW sínc. -> %.1f MW renov.\n', ...
        i, tech_names{config_tech(i)}, zona_names{zona(i)}, Sn(i), Sn_FNCER_vec(i));
end

fprintf('\n  Sistema:\n');
fprintf('    Generadores: %d síncronos + %d eólicos + %d solares\n', num_gen_sinc, num_eolicos, num_solares);
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

case_name_nivel1 = sprintf('N1_Mixto_%s_d%d_f%d_%s_k%s', periodo_str, p_max, factor_cap, config_name, k_str);

[L_n1, E_DNS_n1, des_DNS_n1, LOLP_n1, error_DNS_n1, cont_mcs_n1, T_n1, ...
    T_escenarios, cluster_stats, TopK_Reps] = ...
    SMC_Nivel1_Clustering(sistema_prueba, gen_FNCER, Pr_Falla_Gen, ...
    typeFERNC, Sn_FERNC, CM, VA, Co_FERNC, ...
    r_nivel1, eps_nivel1, LD, dn, case_name_nivel1, num_clusters, h_period);

tiempo_nivel1 = toc(tStart);

%% EVALUACIÓN DE CONFIABILIDAD - NIVEL II

case_name_nivel2 = sprintf('N2_Mixto_%s_d%d_f%d_%s_k%s', periodo_str, p_max, factor_cap, config_name, k_str);

[E_DNS_n2, des_DNS_n2, LOLP_n2, error_DNS_n2, cont_mcs_n2, T_resultados] = ...
    SMC_Nivel2_Muestreo(sistema_prueba, gen_FNCER, ...
    Pr_Falla_Gen, Pr_Falla_LT, typeFERNC, Sn_FERNC, CM, VA, Co_FERNC, ...
    r_nivel2, LD, dn, T_escenarios, cluster_stats, ...
    porcentaje_carga, case_name_nivel2, h_period, TopK_Reps);

tiempo_nivel2 = toc(tStart) - tiempo_nivel1;
tiempo_total = toc(tStart);

%% RESUMEN

fprintf('\nRESUMEN DEL SCRIPT\n');
fprintf('  Config %d: %s\n', config, config_name);
fprintf('  Nivel I:  E[DNS] = %.4f MW, Error = %.2f%%\n', E_DNS_n1, error_DNS_n1*100);
fprintf('  Nivel II: E[DNS] = %.4f MW, Error = %.2f%%\n', E_DNS_n2, error_DNS_n2*100);
fprintf('  Tiempos:  Nivel I = %.2f min | Nivel II = %.2f min | Total = %.2f min\n', ...
    tiempo_nivel1/60, tiempo_nivel2/60, tiempo_total/60);