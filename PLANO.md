# Plano do fork: memória por projeto + troca automática de code agent

Base: `ai-memory` v3.4.3 (Rust, MIT, ~600 mil linhas). O clone está em `ai-memory/`.

## 1. Objetivo

No trabalho você tem 3 code agents, cada um com poucos tokens. O fork precisa:

1. **Guardar a memória do projeto** (o que foi feito, o que falhou, o que falta) num formato que qualquer agente consiga ler.
2. **Trocar de agente automaticamente** quando a cota de um acabar, seguindo uma **ordem configurável** (ex.: Claude Code → Codex → OpenCode), sem você precisar explicar tudo de novo.
3. **Mostrar num painel em `localhost`**, no estilo do Langfuse, o uso de tokens, o modelo, a sessão, o custo e o quanto resta da cota de cada agente.
4. **Enxergar só o projeto onde foi instalado.** Não há visão de outros projetos.

### O que o original já faz e o fork reaproveita

| Necessidade | O que já existe no ai-memory | Lacuna |
|---|---|---|
| Continuar a tarefa em outro agente | `ai-memory run <agente>` (workstreams gerenciados), handoffs e o "dossiê" da sessão anterior (`AI_MEMORY_PREVIOUS_SESSION_HISTORY`), já pensado para cota esgotada | A troca é **manual**: não detecta que a cota acabou, não tem ordem e não relança sozinho |
| Uso de tokens | Livro-razão por resposta no `/web` (input, output e cache, por sessão e por agente) | Só extrai tokens do **Claude Code e do Codex**. Não tem custo, latência, gráficos nem cota |
| Captura | Hooks em `POST /hook`, sanitizador e páginas `sessions/<id>.md` geradas por regras, sem LLM | Ok |
| Escopo por projeto | Toda linha é chave `(workspace, project, path)` | A instalação é **global por usuário** (hooks e MCP em `~/.claude`, `~/.codex`…), e o servidor enxerga todos os projetos |

## 2. Matriz de suporte do fork

| Alvo | Estado no original | Situação no fork |
|---|---|---|
| Claude Code | Completo, inclusive `run` e tokens | **Manter**. Na troca, é alvo de primeira classe |
| Codex | Completo, inclusive `run` e tokens | **Manter**. Na troca, é alvo de primeira classe |
| OpenCode (V1/V2) | Completo; `run` sim; tokens não | **Manter** e adicionar extração de tokens |
| Pi | Extensão TS gerada; `run` sim; tokens não | **Manter** e adicionar extração de tokens |
| Oh My Pi / OMP | Extensão TS gerada; `run` só explícito; tokens não | **Manter**, incluir na troca automática e adicionar tokens |
| Command Code | Hooks e MCP; `run` sim; tokens não | **Manter** e adicionar extração de tokens |
| Cline CLI | Hooks e MCP; **sem `run`** | **Manter** e **criar o adaptador do `run`** (lançar, retomar, ler transcript, tokens) |
| Claude Desktop | Chat: só MCP. Code tab: é o próprio Claude Code | **Manter só como leitor de memória via MCP**. O Chat não tem CLI nem hooks, então não pode entrar na fila de troca. A aba Code já conta como Claude Code |
| Windows via WSL2 | Suportado | **Manter** |
| Windows nativo | Experimental | **Manter** e endurecer, já que é provável no ambiente corporativo: testes, scripts `.ps1` e serviço |
| Linux e macOS | Suportado | Manter como efeito colateral (o código é portável), sem compromisso de empacotamento |

## 3. O que SAI

A ideia é um fork **subtrativo**: remover em fases, com os testes passando a cada fase.

### Integrações com agentes
Sai tudo fora da matriz acima: Cursor, Gemini CLI, Kimi, Kiro, Grok, Devin, Copilot CLI, VS Code Copilot, Antigravity, Zero, ZCode, Factory Droid, Muse, CodeBuddy, IBM Bob, Qwen, Qoder, Zed, DSH, FreeBuff, Prime, Hermes, GrizzyBot, Pool, Crush, Swival e OpenClaw.
Isso afeta `hooks/<agente>/`, os ramos de `install_hooks.rs`, `install_mcp.rs`, `doctor`, `setup`, `uninstall` e os adaptadores em `ai-memory-workstream/src/harness.rs` e `transcript.rs`.

### Visão entre projetos (conflita com "só o projeto instalado")
- Mensagens entre projetos (`memory_message_*`, inbox).
- Perfil entre projetos (`profile`, `scope: "profile"`, `ai_memory_consolidate::profile`).
- Escopo `global` e busca `global=true`, além da página `/web/workstreams` com visão de todos os projetos.
- Comandos de gestão de vários projetos: `list-projects`, `move-project`, `merge-project`, `rename-project`, `purge-project`, `project`, `reorg` e `repair-split`.

### Multiusuário e servidor remoto
Sai: usuários no banco, tokens `aim_`, OIDC/SSO, auth por proxy, API keys de autosserviço, console `management-ui`, autorização por projeto e grants, webhooks de admissão, e o `relay` externo.
Fica só um bearer local gerado no `init`.

### Funcionalidades que gastam LLM
Elas vão contra o objetivo de economizar tokens. Sai o crate `ai-memory-llm` inteiro: Anthropic, OpenAI, Gemini, Copilot, OAuth etc. Saem também, em `ai-memory-consolidate`, o consolidate com LLM, o auto-improve, o dream, o curator, o experience, o reranker LLM, o lint de contradição com LLM e o `memory_explore`.
Os resumos de fim de sessão continuam, porque são feitos por regras.

### Envelhecimento avançado da memória
Sai: o dream, o `cold_cluster`, a belief/salience, a compactação extrativa e a dedup.
Fica uma retenção simples. Isso pode voltar depois, se fizer falta.

### Embeddings locais (candle)
Saem na fase 1: deixam o binário bem maior e a compilação mais lenta, e o FTS5 resolve para um projeto só. Reavaliar depois.

### Segurança do `--yolo` com ai-jail
Sai: `jail.rs` e `jail_contract.rs`. Não existe no Windows nativo e não está no escopo.

### Companions
Sai tudo: importer, relay, wikisync, app de macOS (Swift), SDK TypeScript e instalador desktop (Tauri).

### Empacotamento e distribuição
Sai: Nix, AUR, RPM, Scoop, Homebrew, Docker, `bin/release`, `bin/deploy`, plugins de marketplace (`plugins/`, `render-plugins`) e os workflows de release.

### Outros
- `evals/` (benchmark LongMemEval)
- `export-okf`
- `backup-agents` / `restore-agents`
- `upgrade` automático
- `server_profiles`
- localização Fluent (decidir: manter só pt-BR e en, ou remover)
- documentos de pesquisa e comparação com concorrentes (`docs/research-*`, `comparison.md`, `competitive-parity.md`)

## 4. O que FICA (o núcleo)

| Peça | Crate / arquivo | Por quê |
|---|---|---|
| Tipos de domínio, IDs, sanitizador | `ai-memory-core` | É a fronteira de privacidade, necessária porque o fork vai rodar em código da empresa |
| SQLite, writer actor único, reader pool, migrações | `ai-memory-store` | É a base de tudo. Vale manter as invariantes: um único escritor, índice na mesma transação |
| Wiki markdown com git (fonte da verdade) | `ai-memory-wiki` | É memória legível que qualquer agente consegue usar |
| Ingestão de hooks, roteador, spool, handoff no SessionStart, recuperação de sessão interrompida | `ai-memory-hooks` e `commands/hook*.rs` | É o que alimenta a memória e a continuidade |
| Servidor MCP, reduzido de 27 para cerca de 14 ferramentas | `ai-memory-mcp` | Ficam: `query`, `recent`, `read_page`, `write_page`, `patch_page`, `delete_page`, `read_session_observations`, `status`, `briefing`, `handoff_begin`/`list`/`accept`/`cancel` e `install_self_routing` |
| `ai-memory run` e o dossiê da sessão anterior | `ai-memory-workstream` e `commands/run*.rs` | É a base da troca automática |
| Extração de uso de tokens | `commands/session_usage*.rs` e as tabelas de uso | É a base do painel |
| Interface `/web` | `ai-memory-web` | É a base do painel no estilo Langfuse |
| CLI enxuta | `ai-memory-cli` | Ficam: `init`, `serve`, `setup`, `install-hooks`, `install-mcp`, `run`, `status`, `doctor`, `search`, `read-page`, `write-page`, `handoffs`, `backup`, `restore`, `reindex`, `uninstall` e `completions` |

## 5. O que MUDA

### 5.1 Instalação por projeto
- O **diretório de dados fica dentro do repositório**, em `<repo>/.ai-memory/` (wiki, banco e logs), e entra automaticamente no `.gitignore`. Opcionalmente, a wiki pode ser versionada à parte.
- **Hooks e MCP passam a ser gravados no escopo do projeto**, e não no do usuário. Cada agente tem um caminho de configuração por projeto, que precisa ser confirmado na documentação de cada um:
  - Claude Code: `.claude/settings.json` e `.mcp.json`
  - Codex: config de projeto
  - OpenCode: `opencode.json`
  - Pi e OMP: extensão local
  - Cline: settings do workspace
  - Command Code: `.commandcode/`
  - Onde o agente não tiver escopo de projeto, o hook global **descarta eventos de fora do repositório**.
- **Um servidor por projeto**, com a porta derivada do caminho ou gravada em `.ai-memory/config.toml`. O servidor só aceita o próprio projeto.
- **O schema `(workspace, project, path)` fica igual por dentro**, fixo num único projeto. Arrancar isso do código seria uma reescrita enorme e arriscada. Fixar o projeto entrega o mesmo resultado com uma fração do trabalho.

### 5.2 O `run` vira o orquestrador da troca
Hoje o `run` lança um agente e retoma a sessão nativa. No fork, ele passa a supervisionar o agente e, quando a cota acaba, troca para o próximo da fila (detalhes na seção 6.1).

### 5.3 O painel de tokens vira observabilidade
O ledger atual por resposta é a fonte de dados. A interface é reescrita no estilo Langfuse (seção 6.3).

### 5.4 Escopo do `/web`
Sai: o grafo de links, o inbox, a busca global e a documentação embutida.
Ficam: o projeto (que é único), as sessões, as páginas da memória, os handoffs e o painel novo.

## 6. O que ENTRA (novo)

### 6.1 Troca automática de agente (failover)

**Configuração** (`.ai-memory/config.toml`):
```toml
[failover]
order = ["opencode", "claude-code", "codex"]   # ordem de troca (editável)
mode = "ask"             # ask (padrão: pergunta antes de trocar) | auto | off
switch_at_percent = 95   # aviso/troca preventiva ao atingir 95% do orçamento

[failover.agents.opencode]
model = "qwen"           # a confirmar no trabalho (nome exato do provedor/modelo)

[failover.agents.claude-code]
model = "opus"           # a confirmar no trabalho
# budget_tokens_daily = 2_000_000   # opcional, só se a cota for conhecida
# env = { CLAUDE_CONFIG_DIR = "C:/Users/me/.claude-work" }

[failover.agents.codex]
model = "gpt"            # a confirmar no trabalho
```
A ordem, o modelo e o orçamento de cada agente também podem ser editados pelo painel, que grava neste mesmo arquivo, e pelo comando `failover set`.

**Fluxo:** `ai-memory run` (sem nome de agente) faz o seguinte:
1. Lança o primeiro agente disponível da fila, ou seja, o primeiro que não estiver marcado como "esgotado até HH:MM".
2. Supervisiona o processo filho.
3. Detecta que a cota acabou (veja abaixo).
4. Encerra o agente com segurança e grava um handoff automático: o checkpoint da sessão mais o dossiê do transcript.
5. Marca esse agente como esgotado e registra quando a cota volta. O padrão é a janela de reset informada na mensagem de erro ou, sem isso, o fim do dia.
6. Lança o próximo agente com o pacote de continuidade e o prompt "continue de onde parou". Pelo mecanismo do `AI_MEMORY_PREVIOUS_SESSION_HISTORY`, ele lê exatamente o que o anterior estava fazendo.
7. Grava um **evento de troca** (de → para, motivo, tokens no momento) para o painel.
8. Quando a fila inteira estiver esgotada, avisa e informa quando cada agente volta.

**Ainda não sabemos o que cada agente mostra quando a cota acaba.** Por isso a detecção começa ampla e vai sendo calibrada com o uso:
- Na fase 4 entra um **modo diagnóstico**, ligado por padrão. Todo erro de provedor, toda saída inesperada e todo turno que fica parado são registrados no painel, em "Eventos não classificados", com o texto bruto do erro já sanitizado.
- No trabalho, quando a cota estourar, o painel mostra exatamente o que apareceu. Com um clique, você transforma aquilo em regra: "este padrão significa cota esgotada no OpenCode".
- As regras ficam editáveis em `.ai-memory/quota-rules.toml`, e o projeto já vem com padrões genéricos: `429`, `rate limit`, `quota`, `usage limit`, `insufficient_quota`, `limite`.

**Como detectar que a cota acabou.** São três sinais, combinados:
1. **Erro reportado pelo agente.** É o sinal principal. Ler os eventos de erro do transcript nativo ou dos hooks: rate limit, 429, cota ou limite de uso. O `transcript.rs` já analisa erros de provedor como `"rate limited"`. Precisa de um padrão por agente, **modelado a partir da documentação de cada um**.
2. **Orçamento configurado.** Quando você conhece a cota da empresa, o ledger de tokens dispara a troca preventiva em `switch_at_percent`.
3. **Manual.** Um atalho ou comando `ai-memory run --next` para forçar a troca.

**Comandos novos:**
- `ai-memory failover status`: mostra a fila, quem está esgotado e quando volta.
- `ai-memory failover reset <agente>`: tira o agente do estado "esgotado".
- `ai-memory run --next`: força a troca para o próximo agente.

**Pontos de atenção:**
- Alguns agentes **não saem** quando a cota acaba: mostram a mensagem e ficam esperando. Por isso o supervisor precisa conseguir encerrá-los, o que não é trivial no Windows (ConPTY, árvore de processos).
- O modo `ask` serve para começar com segurança.
- O Cline precisa do adaptador novo do `run` antes de entrar na fila.

### 6.2 Extração de tokens para todos os agentes da matriz
Hoje só existe para Claude Code e Codex. É preciso criar extratores para OpenCode, Pi, OMP, Command Code e Cline, cada um lendo o formato de sessão/transcript do próprio agente, com o link da documentação ao lado do código.
Cada registro precisa ter: agente, modelo, tokens de input/output/cache, latência quando houver, horário e sessão.

### 6.3 Painel no estilo Langfuse em `http://localhost:<porta>/`
- **Visão geral:**
  - tokens por dia, por agente e por modelo (gráfico de linhas ou barras)
  - custo estimado
  - medidor de cota por agente ("Claude Code: 82% do orçamento diário")
  - estado da fila de troca
- **Traces:** sessão → turnos → respostas e chamadas de ferramenta. Cada item mostra modelo, tokens, latência e custo, numa linha do tempo.
- **Sessões:** lista com agente, modelo, duração, total de tokens, se terminou por cota e o handoff gerado.
- **Eventos de troca:** linha do tempo do tipo "10:42 Claude Code esgotou (429) → Codex assumiu".
- **Modelos:** tabela de preços configurável (`[pricing."claude-sonnet-x"] input_per_mtok = …`), usada para calcular o custo.
- **Filtros:** período, agente, modelo e sessão.
- **Atualização:** polling a cada poucos segundos. Já existe atualização a cada 10 s, que pode ser reduzida.
- **Tecnologia:** manter o modelo do original (templates askama renderizados no servidor) com um JS pequeno para os gráficos, por exemplo uma lib de gráficos copiada para dentro do binário (vendorizada). Não precisa de Node no build. Se você preferir um front em React, isso vira outro projeto separado, consumindo uma API JSON nova (`/api/v1/usage`, `/api/v1/traces`).

### 6.4 Instalação de um passo por projeto
`ai-memory setup` executado na raiz do repositório:
- cria `.ai-memory/`
- detecta quais dos agentes da matriz estão instalados
- grava hooks e MCP no escopo do projeto
- sobe o servidor
- abre o painel

No Windows nativo, o serviço sobe por `service-host`, que já existe, ou por uma tarefa agendada por projeto.

### 6.5 Identidade do fork
- Nome novo para o binário e para o crate, para não conflitar com um ai-memory instalado. Exemplos: `agent-relay`, `tokenhop`.
- Variáveis de ambiente com outro prefixo, porta padrão diferente de 49374, e `LICENSE` mantendo o crédito MIT ao Fabio Akita.

## 7. Fases sugeridas

| Fase | Entrega | Critério de pronto |
|---|---|---|
| 0 | Preparar o repositório: remover o `.git` interno, versionar no seu repositório, renomear o binário | `cargo build` e `cargo t` verdes no Windows |
| 1 | **Corte**: integrações fora da matriz, companions, empacotamento, multiusuário, LLM, embeddings, jail, entre-projetos | Build e testes verdes; o binário bem menor |
| 2 | **Escopo por projeto**: diretório de dados no repo, hooks e MCP por projeto, servidor por projeto | Dois repositórios com instalações separadas não se enxergam (teste adversarial) |
| 3 | **Tokens para todos**: extratores de OpenCode, Pi, OMP, Command Code e Cline, mais o adaptador `run` do Cline | Cada agente aparece no ledger com modelo e tokens |
| 4 | **Failover**: config da fila, detecção por agente, supervisor, handoff automático, eventos de troca, modo `ask`/`auto` | Simular um 429 em cada agente e ver o próximo assumir com o contexto |
| 5 | **Painel Langfuse-like**: visão geral, traces, sessões, trocas, preços e cotas | Painel em `localhost` mostrando uma sessão que trocou de agente |
| 6 | Endurecer o Windows nativo, setup de um passo e documentação em pt-BR | Instalação limpa numa máquina Windows do trabalho |

As fases 3 e 5 podem andar em paralelo com a 4, porque mexem em arquivos diferentes.

## 8. Decisões tomadas

1. **Agentes e ordem:** OpenCode (Qwen) → Claude Code (Opus) → Codex (GPT). Tudo editável, porque ainda precisa ser confirmado no trabalho.
2. **Sinal de cota:** ainda desconhecido. A detecção começa ampla, com o modo diagnóstico, e é calibrada no trabalho (seção 6.1).
3. **Troca:** pergunta antes (`mode = "ask"`).
4. **Plataforma:** Windows nativo em primeiro lugar e WSL2 também. A fase 6 (endurecer o Windows nativo) sobe de prioridade e os testes rodam nos dois.
5. **Painel:** mostra **só tokens**. Não há custo em dinheiro, então saem a tabela de preços e o cálculo de custo.
6. **Nome:** a escolher (veja as sugestões na conversa).

### Impacto no plano
- A seção 6.3 perde o item "Modelos/preços" e os campos de custo. O painel fica com tokens por agente, modelo, sessão e turno, além da latência, da cota e das trocas.
- Matriz mínima para testar: OpenCode, Claude Code e Codex, primeiro no Windows nativo e depois no WSL2. Pi, OMP, Command Code, Cline e Claude Desktop continuam suportados, mas ficam fora do caminho crítico.
- A fase 3 começa pelo OpenCode, que não tem extração de tokens hoje e é o primeiro da fila. Claude Code e Codex já funcionam.
