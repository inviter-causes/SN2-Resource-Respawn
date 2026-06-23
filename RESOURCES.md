# แร่ใน Subnautica 2 จัดกลุ่มตามความหายาก

> อ้างอิงจาก Subnautica 2 Wiki (อัปเดต พ.ค.–มิ.ย. 2026)
> เวลาในวงเล็บ คือ ค่า default ของมอด (respawn cooldown ต่อรอบ)

---

## 🟢 Common (default 300s / 5 นาที)

| ทรัพยากร | คืออะไร / ใช้ทำอะไร |
|---|---|
| **Titanium** | แร่พื้นฐานที่ใช้บ่อยที่สุดในเกม สร้างฐาน เครื่องมือ ยาน ทำ Titanium/Plasteel Ingot เก็บด้วยมือได้ หรือถลุงจาก Metal Salvage |
| **Copper** | โลหะนำไฟฟ้า ใช้ทำ Battery, สายไฟ, อิเล็กทรอนิกส์พื้นฐาน มักเกาะผนัง/เพดานถ้ำ ไม่ค่อยอยู่พื้นทราย |
| **Quartz** | คริสตัลซิลิกา ใช้ทำ Glass และชิ้นส่วนอิเล็กทรอนิกส์ เจอเยอะรอบ Coral Dome ในโซน Shallows |
| **Salt** | ใช้ทำ Glass, อาหาร, Isotonic Water, Power Cell เจอตามพื้นทะเลทั่วไป |
| **Water Slug** | สัตว์ passive ใช้ทำน้ำดื่ม (เข้า Fabricator) สแกนแล้วปลดล็อก Water Secretion Biomod เจอมากสุดแถว Lifepod |

---

## 🟡 Medium (default 600s / 10 นาที)

| ทรัพยากร | คืออะไร / ใช้ทำอะไร |
|---|---|
| **Lead** | ในรูปแร่ galena กันรังสี ใช้ทำ Sonic Resonator, Germanium Ingot เก็บครั้งแรกปลดล็อก Sugar of Saturn |
| **Silver** | ใช้ทำ Standard Air Tank, Wiring Kit, System Chip สำคัญมากช่วงต้น-กลาง gate อิเล็กทรอนิกส์หลายอย่าง |
| **Sulfur** | ธาตุที่ 16 ใช้ทำ Strong Acid, Repair Tool, Advanced Wiring Kit อยู่โซนภูเขาไฟ/ปล่องความร้อน |
| **Gold** | ใช้ทำ Thermal Plant, Advanced Wiring Kit อยู่โซนร้อนจัด ต้องมี heat resistance มักเจอคู่กับ Sulfur |
| **Lithium** | ถลุงเป็น Plasteel Ingot สำหรับ depth module จำเป็นถ้าจะดำลึกเกิน 300m |

---

## 🔴 Rare (default 900s / 15 นาที)

| ทรัพยากร | คืออะไร / ใช้ทำอะไร |
|---|---|
| **Atacamite** | คริสตัลเขียว ใช้ทำ Mangalloy Ingot ต้องใช้ Sonic Resonator |
| **Celestine** | แหล่ง Strontium ใช้ทำ Tadpole Depth Module Mk.1 |
| **Conduit Crystal** | ใช้ทำ Bioscanner, Advanced/Entangled Battery อยู่ใต้ Karakorum Power Plant (node ในเกมชื่อ Fulgurite) |
| **Creature Enamel** | ใช้ทำ Enameled Glass ทุบ Enamel Husk ในรัง Needler (node ในเกมชื่อ NeedleSharkNeedles) |

---

## 🟣 Special (default 1800s / 30 นาที)

| ทรัพยากร | คืออะไร / ใช้ทำอะไร |
|---|---|
| **Axum Bacterial Culture** | ใช้สร้าง Metal Farm หายากที่สุดในเกม มีแค่ ~5 ชิ้น ปกติไม่ respawn (มอดปลดล็อกให้เกิดใหม่ได้) |
| **Troilite** ⚠️ *(ยังทำไม่ได้)* | ใช้ทำ Mangalloy Ingot, Entangled Power Cell อยู่โซน Karakorum Metal Farms ปั๊มผ่าน Metal Farm ได้ อย่าใช้ชิ้นสุดท้าย |

---

## ⚠️ ทำไม Troilite ยังทำไม่ได้

Troilite เก็บจาก **Mineralized Clinker** ซึ่งในเกมเป็น `StaticMeshActor` (วัตถุ mesh ธรรมดา)
ไม่ใช่ resource node แบบแร่อื่น จึง **ไม่มี flag `bHasBeenGathered`** ให้มอดรีเซ็ต — กลไก respawn
ของมอดเลยจับมันไม่ได้ (ตรงกับที่ Wiki บอกว่า Troilite ออกแบบให้ finite โดยตั้งใจ)

ในเมนูจะโชว์เป็น `Troilite (unsupported)` ปิดอยู่และกดแล้วไม่มีผล — ไว้เผื่อวันหลังเจอวิธีจัดการ
StaticMeshActor ก็จะเปิดใช้งานได้

## ของที่อยู่นอกขอบเขต

| รายการ | เหตุผล |
|---|---|
| **Metal Salvage** | ของหล่นพื้น (pickup) ไม่ใช่ node ติดที่ |
| **Lithium Pearl** | ผูกกับสัตว์ Clamthulu — ตั้งใจข้าม (Lithium ธรรมดายังทำงานปกติ) |
