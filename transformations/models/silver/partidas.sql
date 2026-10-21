-- Camada silver: partidas tipadas, limpas e com clubes padronizados.
-- Mantém todo o histórico (desde 2003); o recorte de análise acontece na gold.

with ultima_carga as (
    -- Lê apenas a carga mais recente da bronze, evitando duplicar partidas
    -- quando houver mais de uma data_carga no S3
    select *
    from {{ source('bronze', 'partidas') }}
    where data_carga = (select max(data_carga) from {{ source('bronze', 'partidas') }})
),

tipado as (
    select
        cast(id as integer)                                   as partida_id,
        cast(rodata as integer)                               as rodada,   -- "rodata" é erro de digitação na origem
        cast(date_parse(data, '%d/%m/%Y') as date)            as data_partida,
        nullif(trim(hora), '')                                as hora,
        trim(mandante)                                        as mandante_origem,
        trim(visitante)                                       as visitante_origem,
        cast(mandante_placar as integer)                      as gols_mandante,
        cast(visitante_placar as integer)                     as gols_visitante,
        trim(vencedor)                                        as vencedor_origem,
        nullif(trim(arena), '')                               as estadio,  -- origem tem espaços à esquerda
        nullif(trim(formacao_mandante), '')                   as formacao_mandante,
        nullif(trim(formacao_visitante), '')                  as formacao_visitante,
        nullif(trim(tecnico_mandante), '')                    as tecnico_mandante,
        nullif(trim(tecnico_visitante), '')                   as tecnico_visitante,
        data_carga
    from ultima_carga
),

com_temporada as (
    select
        *,
        -- Temporada != ano civil. Nenhuma temporada começa antes de abril, então
        -- jogos de jan-mar pertencem à temporada anterior (ex.: 2020 terminou em fev/2021).
        case
            when month(data_partida) <= 3 then year(data_partida) - 1
            else year(data_partida)
        end as temporada
    from tipado
)

select
    p.partida_id,
    p.temporada,
    p.rodada,
    p.data_partida,
    p.hora,

    cm.clube_id                 as mandante_id,
    cm.clube                    as mandante,
    cm.uf                       as uf_mandante,
    cv.clube_id                 as visitante_id,
    cv.clube                    as visitante,
    cv.uf                       as uf_visitante,

    p.gols_mandante,
    p.gols_visitante,
    case
        when p.gols_mandante > p.gols_visitante then 'M'
        when p.gols_mandante < p.gols_visitante then 'V'
        else 'E'
    end                         as resultado,  -- derivado do placar (M=mandante, V=visitante, E=empate)
    p.vencedor_origem,

    p.estadio,
    p.formacao_mandante,
    p.formacao_visitante,
    p.tecnico_mandante,
    p.tecnico_visitante,

    p.mandante_origem,
    p.visitante_origem,
    p.data_carga
from com_temporada p
left join {{ ref('clubes') }} cm on p.mandante_origem = cm.nome_origem
left join {{ ref('clubes') }} cv on p.visitante_origem = cv.nome_origem
