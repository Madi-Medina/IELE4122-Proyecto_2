function mpc_new = Generadores_deslastre(mpc)
% Agrega generadores ficticios de alta penalización en cada bus con carga
% para permitir el cálculo de DNS (Demanda No Suministrada) mediante OPF

% Recibe:
%   mpc: estructura de caso MATPOWER. Type: struct.

% Retorna:
%   mpc_new: estructura de caso MATPOWER con generadores de deslastre agregados. Type: struct.
%            Campo adicional: idx_deslastre con índices de generadores ficticios

    % Cálculo de VOLL (Value of Lost Load)
    costos_lineales = mpc.gencost(mpc.gencost(:,1)==2, 6);
    
    if isempty(costos_lineales)
        costo_max = 100;
    else
        costo_max = max(costos_lineales);
    end
    
    VOLL = costo_max * 1000;
    
    if VOLL > 1000000
        VOLL = 1000000;
    end
    
    % Identificación de buses con carga
    buses_con_carga = find(mpc.bus(:, 3) > 0);
    num_buses = length(buses_con_carga);
    
    % Creación de generadores ficticios
    nuevos_gen = zeros(num_buses, 21);
    
    for i = 1:num_buses
        bus_num = buses_con_carga(i);
        bus_idx = find(mpc.bus(:, 1) == bus_num, 1);
        
        demanda_P = mpc.bus(bus_idx, 3);
        Pmax = demanda_P * 1.2;
        
        nuevos_gen(i, 1)  = bus_num;
        nuevos_gen(i, 2)  = 0;
        nuevos_gen(i, 3)  = 0;
        nuevos_gen(i, 4)  = Pmax;
        nuevos_gen(i, 5)  = 0;
        nuevos_gen(i, 6)  = 1.0;
        nuevos_gen(i, 7)  = 100;
        nuevos_gen(i, 8)  = 1;
        nuevos_gen(i, 9)  = Pmax;
        nuevos_gen(i, 10) = 0;
    end
    
    % Creación de curvas de costo con penalización alta
    nuevos_gencost = zeros(num_buses, 7);
    
    for i = 1:num_buses
        nuevos_gencost(i, 1) = 2;
        nuevos_gencost(i, 2) = 0;
        nuevos_gencost(i, 3) = 0;
        nuevos_gencost(i, 4) = 3;
        nuevos_gencost(i, 5) = 0;
        nuevos_gencost(i, 6) = VOLL;
        nuevos_gencost(i, 7) = 0;
    end
    
    % Incorporación de generadores ficticios al caso
    mpc_new = mpc;
    mpc_new.gen = [mpc.gen; nuevos_gen];
    mpc_new.gencost = [mpc.gencost; nuevos_gencost];
    mpc_new.idx_deslastre = (size(mpc.gen,1)+1):(size(mpc.gen,1)+num_buses);

end

