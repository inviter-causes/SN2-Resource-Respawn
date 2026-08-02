# AGENTS.md — SN2-Resource-Respawn

กติกาสำหรับ **AI agent ทุกยี่ห้อ** (Claude Code / Codex) ที่เข้ามาทำงานใน repo นี้
**กติกาฉบับเต็มอยู่ที่หอบังคับการ** → [`../Bon-Skill-Manager/AGENTS.md`](../Bon-Skill-Manager/AGENTS.md)

> **Bon ไม่ใช่โปรแกรมเมอร์ — agent ต้องรันคำสั่งให้เสมอ ไม่ใช่สอนให้รันเอง**

## repo นี้คืออะไร

Mod **ResourceRespawn** ของ Subnautica 2 (UE4SS + Lua) — **ปล่อยจริงแล้ว v2.1.0**
อยู่บน Nexus (mods/420) มีคนใช้จริง

## เริ่มงาน

1. `git pull`
2. อ่าน [README.md](README.md) → [PROGRESS.md](PROGRESS.md) (ไฟล์สถานะ)
3. `CHANGELOG.md` บอกว่าแต่ละเวอร์ชันเปลี่ยนอะไร · `NEXUS.txt` คือข้อความบนหน้า Nexus

## จบงาน

1. อัปเดต [PROGRESS.md](PROGRESS.md) — ทำอะไรไป / ทำไม / ค้างอะไร / กับดักที่เจอ
2. ถ้าปล่อยเวอร์ชันใหม่: อัปเดต `CHANGELOG.md` + `NEXUS.txt` + `STATUS.md` ที่หอบังคับการ
3. commit + push **ทันที** (ห้ามค้างไว้ไม่ push)

## ทำงานหลาย agent — ห้ามพลาด

- **ห้ามค้างงานไว้โดยไม่ push** — agent อีกตัว pull ไปไม่เห็น แล้วแก้ทับ = conflict
- **repo หนึ่งตัว ทำทีละ agent**
- **commit message ระบุ agent ที่ทำ** (`Co-Authored-By: ...`)
- **push ไม่ผ่านให้ `git pull --rebase`** · ห้าม force push เด็ดขาด

## ข้อห้ามที่พลาดบ่อย

- ❌ ห้ามลบ `.gitattributes` (บังคับ LF — หายแล้วเกิด CRLF churn ทั้ง repo บน Windows)
- ❌ ห้าม clone repo นี้ซ้ำไว้ที่อื่น — ที่อยู่มีที่เดียวคือ `00_Claude Code/`
- ❌ **agent ไม่อัปโหลดขึ้น Nexus / ไม่ตอบคอมเมนต์แทน Bon** — เตรียมไฟล์กับข้อความให้
  แล้ว Bon กดเอง (มอดนี้มีผู้ใช้จริง ปล่อยพลาด = กระทบคนอื่น)
- ❌ ห้ามลบไฟล์ของ Bon โดยไม่ถาม

## เฉพาะ repo นี้

- แพ็กด้วย `./package.sh` · ติดตั้งลงเกมด้วย `./deploy.sh` (รันจาก **Git Bash**)
  ต้องมี **Windows + เกมติดตั้ง + UE4SS** · เครื่องที่ไม่มีให้บอก Bon อย่าเดาว่าผ่าน
- มี `tests/` — แก้ logic แล้วรันเทสก่อน commit
- แก้ Lua แล้ว **ต้องรีสตาร์ทเกม** ถึงจะเห็นผล
