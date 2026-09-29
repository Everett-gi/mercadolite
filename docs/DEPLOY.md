# Deploy — MercadoLite

A infraestrutura é a mesma de todo o portfólio: uma VM Oracle Cloud (Always Free) rodando
Docker, com Caddy fazendo HTTPS automático.

## A base

O passo a passo completo — criar a conta Oracle, gerar a chave SSH, criar a VM ARM, abrir
o firewall (o duplo firewall!), instalar Docker, configurar DuckDNS e subir com Caddy —
está no **[`docs/DEPLOY.md` do DocSage](https://github.com/Everett-gi/docsage/blob/main/docs/DEPLOY.md)**. Ele serve para qualquer
projeto do portfólio; troque só o repositório e o domínio.

Resumo do fluxo, uma vez que a VM já existe:

```bash
ssh docsage                                   # conecta na VM (apelido criado no guia do DocSage)
git clone https://github.com/Everett-gi/mercadolite.git && cd mercadolite
nano .env                                      # .env de PRODUÇÃO, criado aqui (não vem do Git)
chmod 600 .env
docker compose -f docker-compose.prod.yml up -d --build
```

## Rodando vários projetos na mesma VM

A VM Always Free (2 OCPU / 12 GB ARM) aguenta poucos serviços vivos ao mesmo tempo —
principalmente os de Java, que consomem mais memória. Estratégia recomendada:

- Mantenha **3 a 5 projetos vivos** (os carros-chefe) e os demais prontos para subir.
- **Um Caddy só** para a VM toda, com um bloco por domínio, roteando para cada aplicação.
- Cada projeto usa seu próprio subdomínio DuckDNS (ex.: `authhub-gil.duckdns.org`).
- Se faltar memória, limite o heap dos apps Java (`-XX:MaxRAMPercentage=50`) e use swap.

Exemplo de um Caddyfile central na VM (fora dos projetos), com vários apps:

```
authhub-gil.duckdns.org   { reverse_proxy authhub-app:8080 }
docsage-gil.duckdns.org   { reverse_proxy docsage-app:8080 }
mercado-gil.duckdns.org   { reverse_proxy mercadolite-app:3000 }
```

## Notas de Ruby (Rails)

- Porta interna: **3000** (o `Dockerfile` gerado pelo Rails já faz `EXPOSE 3000` e roda como
  usuário não-root).
- O projeto **não usa** `config/credentials.yml.enc` nem `RAILS_MASTER_KEY`: todo segredo vem
  de variável de ambiente. No `.env` de produção, defina pelo menos `SECRET_KEY_BASE` (gere
  com `bin/rails secret`) e as variáveis do banco (`DATABASE_HOST`, `DATABASE_USERNAME`,
  `DATABASE_PASSWORD`). Veja o `.env.example`.
- As **migrations** rodam sozinhas: o `bin/docker-entrypoint` executa `bin/rails db:prepare`
  antes de subir o servidor. O **precompile dos assets** acontece no build da imagem.
- A imagem já define `RAILS_ENV=production`, e o Rails 8.1 serve os arquivos de `public/`
  sozinho (`public_file_server.enabled` é `true` por padrão). O Caddy também pode servi-los.
- Em produção o Rails usa 3 bancos no mesmo PostgreSQL: `mercadolite_production`,
  `mercadolite_production_cache` (Solid Cache) e `mercadolite_production_queue` (Solid Queue).
  O `db:prepare` cria os três.

## Checklist de deploy

- [ ] Secret Scanning + Push Protection ativos no repositório
- [ ] `.env` de produção criado **na VM** (nunca versionado), com `chmod 600`
- [ ] Subdomínio DuckDNS apontando para o IP da VM (confirmado com `dig`)
- [ ] Portas 80/443 abertas na Security List **e** no firewall do sistema (iptables)
- [ ] `docker compose -f docker-compose.prod.yml up -d --build` sem erros
- [ ] HTTPS funcionando (cadeado no navegador, sem aviso)
- [ ] Backup do banco agendado (cron) e, idealmente, enviado para storage externo
