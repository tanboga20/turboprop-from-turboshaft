**English** | [Türkçe](README.tr.md)

# Turboprop Power Transmission

Mechanical design of the power transmission and accessory drives of a 1,200 shp turboprop, from the power turbine shaft to the propeller flange: shafts and bearings, the reduction gearbox (RGB), accessory drives and lubrication.

This is a theoretical student design study. It follows an aero-engine design process (requirements, concept trades, detail design and analysis, manufacturing drawings) with formal reviews at each gate. Nothing is manufactured, and nothing here is meant for use on a real aircraft.

## Scenario

- **Core:** a T700-class turboshaft gas generator, taken as given and converted to a turboprop. The GE CT7 turboprop family is the precedent.
- **Customer:** a Heron TP-class single-engine pusher UAV.
- **Baseline numbers:**

| Quantity | Value | Basis |
| --- | --- | --- |
| Power, flat-rated | 1,200 shp (895 kW) | Customer class (PT6A-67A on Heron TP) |
| Power turbine speed | 22,000 rpm | CT7-9 type certificate data sheet |
| Propeller speed | 1,700 rpm | PT6A-67A type certificate data sheet |
| Reduction ratio | ≈12.9:1 | 22,000 / 1,700 |
| Power turbine torque | ≈389 N·m | 895 kW at 22,000 rpm |
| Propeller torque | ≈5.03 kN·m | 895 kW at 1,700 rpm |

## Plan

| Phase | Content | Review |
| --- | --- | --- |
| 0 | Literature, certification basis, requirements and traceability matrix | SRR |
| 1 | Concept and trade studies: installation layout, RGB architecture, lubrication | PDR |
| 2 | Detail design and analysis: gears, shafts, bearings, rotordynamics, lubrication | CDR |
| 3 | GD&T drawings, verification plan, comparison with the CT7-9, final report | Final review |

**Status:** Complete. All four phases are closed (SRR, PDR, CDR and the final review). Requirements v4: 69 requirements; 34 met, 19 met in part, 7 open (tests and partner values) and 9 waiting for a supplier value (TBD); none at risk. The design: rear-drive installation, an offset helical first stage followed by a four-planet planetary stage (31/110 | 45/37/119, 12.93:1), 109.95 kg, 98.71 % efficiency.

**Method:** The requirements, trade-offs and all design decisions are Hamit Tanboğa's. The calculation tools, CAD scripts and report drafts were developed with the help of an AI assistant and reviewed by the author; every MATLAB tool is checked against an independent Python reference.

**CAD:** The CATIA model is the Phase 3 model of steps 3.1 to 3.5. Later detail changes (case flange bolt circle 308 mm, damping-ring groove of the first-stage gear, nose parts P116 to P120 and the items of open item OI-16) are in the calculations and drawing tables but not yet in the model.

## Repository layout

| Folder | Content |
| --- | --- |
| [`docs/`](docs/) | Final report (English and Turkish), figures and short phase notes |
| [`requirements/`](requirements/) | Requirements and traceability matrix |
| [`manufacturing/`](manufacturing/) | Bill of materials, materials, processes, manufacturing routes and standard parts (step 3.4) |
| [`calc/`](calc/) | MATLAB design calculations: gears, shafts, bearings, lubrication |
| [`rotordynamics/`](rotordynamics/) | Python rotordynamics models built with ROSS |
| [`cad/`](cad/) | CAD models and drawings |

## Data and conventions

- Public sources only: EASA type certificate data sheets, NASA technical reports, patents, U.S. Army field manuals and manufacturer brochures. Every number in the reports cites its source.
- SI units throughout; shp and rpm are kept where the sources use them.
- Every report and README is written in Turkish and English.
