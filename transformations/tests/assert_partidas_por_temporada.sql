-- Desde 2006 (20 clubes) toda temporada completa tem 380 partidas.
-- Exceções documentadas ficam em vars.temporadas_excecao (dbt_project.yml).
-- A temporada mais recente é ignorada se estiver em andamento.
-- O teste falha se retornar alguma linha.

{% set excecoes = var('temporadas_excecao') %}

with contagem as (
    select temporada, count(*) as partidas
    from {{ ref('partidas') }}
    where temporada >= 2006
    group by temporada
),

esperado as (
    select
        temporada,
        partidas,
        case temporada
            {% for temporada, qtd in excecoes.items() %}
            when {{ temporada }} then {{ qtd }}
            {% endfor %}
            else 380
        end as partidas_esperadas
    from contagem
)

select *
from esperado
where partidas != partidas_esperadas
  and temporada < (select max(temporada) from contagem)
