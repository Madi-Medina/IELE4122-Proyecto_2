function decimal = bi2de(binary)
% Convierte un vector binario a su representación decimal equivalente
% utilizando el formato LSB-first (bit menos significativo primero)

% Recibe:
%   binary: vector binario donde cada elemento es 0 o 1. 
%           El primer elemento es el bit menos significativo (LSB).
%           Type: vector (1xn) double o logical.

% Retorna:
%   decimal: valor decimal equivalente. Type: double.

    decimal = 0;
    for i = 1:length(binary)
        if binary(i)
            decimal = decimal + 2^(i-1);
        end
    end
end
