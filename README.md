# locanotes

Sistema de anotações - teste técnico Locaweb com autenticação JWT, paginação cursor, i18n pt-BR/en, modo claro/escuro e Docker-first dev workflow. Backend Rails 8.1 API-only + frontend Vue 3.5 SPA.

## Stack

| Camada | Versão / lib |
|---|---|
| Backend | Ruby 3.4.9 · Rails 8.1.3 (API-only) · PostgreSQL 18 |
| Auth | JWT HS256 · Rails 8 authentication generator (Session.id = jti) |
| Frontend | Vue 3.5 · TypeScript 6 (strict) · Vite · Pinia · Vue Router · vue-i18n · axios |
| Tests | RSpec + FactoryBot + Shoulda Matchers (back) · Vitest + Vue Test Utils + MSW (front) |
| Lint / Security | RuboCop · ESLint · Oxlint · Prettier · Brakeman · bundler-audit |
| Infra | Docker Compose · Rack::Attack (memory store) · Pundit · rack-cors |

## Pré-requisitos

Apenas duas coisas no host:

- **Docker Desktop** com Compose v2
- **GNU Make**

Ruby, Node e Postgres rodam dentro dos containers — sem instalação local.

## Rodando do zero

```bash
git clone <url-do-repositorio>
cd locanotes
make up
```

Na primeira vez: cria `.env` a partir do `.env.example`, builda as 3 imagens, prepara o banco e sobe tudo. Daí em diante reabre em ~10s.

Endpoints:

- API: <http://localhost:3000> (`/up` é o healthcheck)
- App: <http://localhost:5173>

## Comandos do Makefile

```
make up         Sobe tudo (foreground, com logs)
make up-d       Sobe em background
make down       Derruba (mantém volumes)
make rebuild    Estado limpo: down -v + up

make test       Todos os testes (backend + frontend)
make lint       RuboCop + ESLint + Oxlint

make migrate    bin/rails db:migrate
make console    bin/rails console
make psql       psql no banco de dev
```

`make help` lista os 22 targets disponíveis.

## Testes

| | Quantidade | Cobertura |
|---|---|---|
| Backend (RSpec) | 178 specs | models, JWT service, Authentication concern, todos os endpoints, paginação, rate limiting, i18n, security headers, cross-user, edge cases |
| Frontend (Vitest + MSW) | 84 specs | auth store, interceptors, router guards, todas as views, NoteForm, language/theme switchers |

Edge cases cobertos: boundaries exatos (title 120/121, content 10000/10001), tokens expirados/manipulados/`alg=none`, refresh usado como access, Session destruída, cross-user → 404, unicode/emoji preservados, whitespace strip, network failure, 429, paginação sem duplicar/pular entre páginas.

## Decisões em destaque

### Autenticação: JWT + Session no banco
JWT carrega `jti = session.id`. Logout destrói a Session → próxima request com o mesmo token retorna 401, mesmo antes do `exp` vencer. Ganha **revogação imediata** e _device list_ sem Redis; paga ~1ms de lookup PG (PK indexada) por request autenticada. Validado por smoke E2E: register → login → logout → mesmo token volta 401.

### Paginação por cursor (não offset)
Cursor base64 de `(created_at, id)` + tuple comparison no Postgres sob o índice composto `(user_id, created_at, id)`. Inserções concorrentes não causam pulos ou duplicações — problema clássico do `OFFSET`.

### Sem Redis no escopo
Rack::Attack usa memory store. Decisão para MVP single-instance + Postgres já no stack. Em produção multi-instance eu adicionaria Redis para (1) Rack::Attack distribuído, (2) cache de Sessions quentes — sem mudar o desenho de auth.

### Docker-first dev workflow
Ruby 3.4.9 e Node 24 vivem dentro dos containers. Avaliador roda `make up` e o app sobe sem "depende de versão X instalada local". Cada serviço tem `Dockerfile.dev` (rebuild rápido) e o backend mantém também `Dockerfile.prod` (multi-stage Kamal-ready).

### Removidos `kamal` e `thruster`
Vinham por default no `rails new`, traziam **12 HIGH + 1 CRITICAL** CVEs em binários Go embutidos. Sem uso real no escopo (sem deploy nessa entrega) — removidos via commit `security:` explícito.

### Anti-enumeration na auth
- Login com senha errada e email inexistente retornam **a mesma mensagem genérica** ("Email ou senha incorretos")
- Acesso a nota de outro usuário retorna **404 not_found**, não 403 — não vazamos existência

### i18n bilíngue ponta-a-ponta
- Backend: pt-BR (default) + en, despacho via `Accept-Language`
- Frontend: vue-i18n com strings em JSON + switcher persistente em localStorage
- axios encaminha o idioma escolhido para o backend automaticamente

### Tema claro/escuro selecionável
3 opções (Sistema / Claro / Escuro), persistido em localStorage, aplicado via `<html data-theme>`. "Sistema" honra `prefers-color-scheme` do OS.

## Segurança

- **Auth**: JWT HS256 com `alg=none` rejeitado por spec dedicado; access (15 min) + refresh (7 dias); revogação imediata por destruição de Session
- **Autorização**: Pundit policies; cross-user → 404 (anti-enumeration)
- **Rate limiting**: 5 logins/min/IP, 60 requests/min/token (Rack::Attack)
- **Response headers**: `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `X-Permitted-Cross-Domain-Policies: none`, HSTS em produção via `force_ssl`
- **CORS**: origin allowlist via env var (`FRONTEND_ORIGIN`)
- **Senha**: bcrypt; mínimo 8 chars com pelo menos uma letra e um número; nunca retornada nas responses
- **Estática**: Brakeman + bundler-audit rodam em CI (0 warnings hoje)
- **CVEs `won't fix` em libs do Debian**: ~10 HIGHs em `libc6`/`libgnutls30t64`/etc. — marcadas pelo Debian como não-corrigíveis nesse major da distro; não exploitáveis no surface de uma API Rails

## CI

GitHub Actions com 3 jobs em paralelo em cada PR / push para main:

- **backend**: Postgres 18 + RuboCop + Brakeman + bundler-audit + 178 specs RSpec
- **frontend**: type-check + ESLint + Oxlint + 84 specs Vitest + production build
- **docker**: `docker compose build` valida que os 3 Dockerfiles compilam em ambiente limpo

Dependabot semanal para `bundler`, `npm`, `docker` e `github-actions`.

## Estrutura do repo

```
locanotes/
├── backend/                              Rails 8.1 API
│   ├── app/{controllers,models,policies,services}
│   ├── spec/{models,services,controllers,policies,requests}
│   ├── Dockerfile.dev                    imagem dev (rebuild rápido)
│   └── Dockerfile.prod                   multi-stage Kamal-ready
├── frontend/                             Vue 3.5 SPA
│   ├── src/{api,components,composables,stores,views,locales}
│   └── Dockerfile.dev
├── .github/workflows/ci.yml              3 jobs em paralelo
├── docker-compose.yml                    db + backend + frontend
├── Makefile                              22 targets para o dia-a-dia
└── .env.example
```

## Limitações conhecidas

- **Refresh token em localStorage** (frontend): simples mas vulnerável a XSS. Em produção: refresh em cookie `httpOnly` + access em memória.
- **Rack::Attack memory store**: não compartilhado entre instâncias. Single-instance funciona; multi-instance precisa Redis.
- **CVEs `won't fix` em libs do OS**: documentado acima; mitigação real exige upgrade do major do Debian.
- **Sem busca/filtro**: fora do escopo do teste (pediu criar/listar). Próxima feature natural.
