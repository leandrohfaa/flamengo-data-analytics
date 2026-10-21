-- O vencedor informado pela origem deve bater com o placar.
-- Na origem, empate é representado por "-".
-- Severidade "warn": a origem tem 1 caso conhecido (partida 1114, Brasiliense 0x1 Vasco, 2005)
-- com vencedor "-" apesar do placar. A silver confia no placar (coluna "resultado").

{{ config(severity='warn') }}

select partida_id, temporada, mandante_origem, visitante_origem,
       gols_mandante, gols_visitante, vencedor_origem, resultado
from {{ ref('partidas') }}
where not (
       (resultado = 'M' and vencedor_origem = mandante_origem)
    or (resultado = 'V' and vencedor_origem = visitante_origem)
    or (resultado = 'E' and vencedor_origem = '-')
)
