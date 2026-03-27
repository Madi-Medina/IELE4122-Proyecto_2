function [DNS, LOLP] = indices_confiabilidad(result_opf, num_gen_originales)
% Calcula índices de confiabilidad (DNS y LOLP) a partir de los resultados
% del OPF con generadores ficticios de deslastre

% Recibe:
%   result_opf: estructura de resultados de runopf. Type: struct.
%   num_gen_originales: número de generadores reales antes de agregar ficticios. Type: double.

% Retorna:
%   DNS: demanda no suministrada [MW]. Type: double.
%   LOLP: indicador de pérdida de carga (0=sin falla, 1=con falla). Type: double.
    
    % Verificación de convergencia del OPF
    if ~result_opf.success
        DNS = sum(result_opf.bus(:, 3));
        LOLP = 1;
        return;
    end
    
    % Identificación de generadores ficticios
    idx_deslastre = (num_gen_originales + 1):size(result_opf.gen, 1);
    
    % Cálculo de DNS como suma de generación ficticia
    DNS = max(0, sum(result_opf.gen(idx_deslastre, 2)));

    % Cálculo de LOLP
    if DNS>0
        LOLP = 1;
    else
        LOLP = 0;
    end
    
end