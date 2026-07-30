import { execFileSync } from 'node:child_process';

const project = 'insurance-1178e';
const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const importedAt = new Date().toISOString();

const slug = (value) => value.toLowerCase().replace(/&/g, ' and ').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const pct = (label, percent, extra = {}) => ({ label, percent, ...extra });
const band = (label, from, to, percent, metric = 'premium', extra = {}) => ({ label, metric, from, ...(to == null ? {} : { to }), percent, ...extra });

const companies = [
  ['IFFCO Tokio General Insurance Company Limited', ['General', 'Motor']],
  ['SBI General Insurance Company Limited', ['General', 'Motor', 'Health']],
  ['Bajaj Allianz General Insurance Company Limited', ['General', 'Motor']],
  ['HDFC ERGO General Insurance Company Limited', ['General', 'Motor', 'Health', 'Travel']],
  ['ICICI Lombard General Insurance Company Limited', ['General', 'Motor', 'Health', 'Travel', 'Home']],
  ['United India Insurance Company Limited', ['General', 'Motor', 'Marine']],
  ['The New India Assurance Company Limited', ['General', 'Motor', 'Health', 'Engineering', 'Rural']],
  ['Bajaj Allianz Life Insurance Company Limited', ['Life']],
  ['ICICI Prudential Life Insurance Company Limited', ['Life']],
  ['Aditya Birla Sun Life Insurance Company Limited', ['Life']],
  ['Axis Max Life Insurance Limited', ['Life']],
  ['SBI Life Insurance Company Limited', ['Life']],
  ['IndusInd Nippon Life Insurance Company Limited', ['Life']],
  ['Niva Bupa Health Insurance Company Limited', ['Health']],
  ['Aditya Birla Health Insurance Company Limited', ['Health']],
  ['Care Health Insurance Limited', ['Health']],
  ['Star Health and Allied Insurance Company Limited', ['Health', 'Travel', 'Group']],
  ['Galaxy Health Insurance Company Limited', ['Health']],
  ['ManipalCigna Health Insurance Company Limited', ['Health']],
].map(([companyName, departments]) => ({
  id: slug(companyName), companyName, departments, companyType: departments.length === 1 ? departments[0] : 'All',
  registrationNumber: `IMPORTED-${slug(companyName).toUpperCase()}`, status: 'Active', source: 'User supplied commission workbooks',
}));

const company = (contains) => companies.find((c) => c.companyName.toLowerCase().includes(contains.toLowerCase()));
const policies = [];
function addPolicy(companyNeedle, department, planName, policyCode, rules, sourceSheet, extra = {}) {
  const c = company(companyNeedle);
  const category = department === 'Life' ? 'Life' : department === 'Health' ? 'Health' : department;
  policies.push({
    id: slug(`${policyCode}-${c.id}`), companyId: c.id, companyName: c.companyName,
    departmentId: `${c.id}-${slug(department)}`, departmentName: department,
    planName, policyCode, category, policySection: extra.policySection ?? department,
    description: extra.description ?? `Imported from ${sourceSheet}`,
    status: 'Active', renewalCommission: extra.renewalCommission ?? 0,
    commissionRules: rules, rawCommissionStructure: extra.raw ?? rules.map((r) => r.label).join('\n'),
    sourceWorkbook: extra.workbook, sourceSheet, sourceImportedAt: importedAt,
    searchKey: `${planName} ${policyCode} ${c.companyName} ${department}`.toLowerCase(),
  });
}

// Health workbook. Rates stored as percentages (0.25 in Excel means 25%).
addPolicy('SBI General', 'Health', 'SBI General Health Portfolio', 'SBI-HLTH-PORTFOLIO', [
  band('Below Rs 10 lakh sum insured', 0, 999999, 25, 'sumInsured'),
  band('Rs 10 lakh and above sum insured', 1000000, null, 42.5, 'sumInsured'),
  pct('Port business', 15, { conditions: { businessType: 'Port' } }),
], 'SBI GENERAL(Health)', { workbook: 'Health Insurance (2).xlsx', raw: 'Below 10 Laks SA--25%\nAbove 10 Laks SA--42.5%\nIf 10 laks business crossed then additional 2.5%\nPORT--15%' });
addPolicy('Niva Bupa', 'Health', 'Niva Bupa Fresh and Port Business', 'NIVA-FRESH-PORT', [
  band('Rs 50,000 to 124,999 monthly business', 50000, 124999, 22.5, 'monthlyBusiness'),
  band('Rs 125,000 to 199,999 monthly business', 125000, 199999, 25, 'monthlyBusiness'),
  band('Rs 200,000 to 299,999 monthly business', 200000, 299999, 27.5, 'monthlyBusiness'),
  band('Rs 300,000 to 499,999 monthly business', 300000, 499999, 30, 'monthlyBusiness'),
  band('Rs 500,000 and above monthly business', 500000, null, 35, 'monthlyBusiness'),
], 'Niva Bupa', { workbook: 'Health Insurance (2).xlsx', renewalCommission: 2, raw: 'Fresh & Port monthly slabs: 50k-124999 22.5%; 125k-199999 25%; 200k-299999 27.5%; 300k-499999 30%; 500k+ 35%. Renewal: up to 85% retention 2%; 90%+ 3%.' });
addPolicy('Aditya Birla Health', 'Health', 'Aditya Birla Health Fresh Business', 'ABHI-FRESH', [
  band('Rs 0 to 25,000', 0, 24999, 4), band('Rs 25,000 to 50,000', 25000, 50000, 6),
  band('Rs 100,000 to 149,999', 100000, 149999, 8), band('Rs 150,000 to 199,999', 150000, 199999, 10),
  band('Rs 200,000 to 299,999', 200000, 299999, 12), band('Rs 300,000 and above', 300000, null, 27),
  band('Quarterly Rs 17 lakh new business', 1700000, null, 39, 'quarterlyBusiness'),
  pct('Portable business - no commission', 0, { conditions: { businessType: 'Port' } }),
], 'ABHI', { workbook: 'Health Insurance (2).xlsx' });
addPolicy('ICICI Lombard', 'Health', 'ICICI Lombard Health Fresh Business', 'ICICI-HLTH-FRESH', [
  band('Rs 0 to 19,999', 0, 19999, 15), band('Rs 20,000 to 60,000', 20000, 60000, 17.5),
  band('Rs 60,001 to 80,000', 60001, 80000, 25), band('Rs 80,001 to 100,000', 80001, 100000, 27.5),
  band('Rs 100,001 to 150,000', 100001, 150000, 30), band('Rs 150,000 and above', 150000, null, 32.5),
  pct('Port business', 15, { conditions: { businessType: 'Port' } }),
], 'ICICI Lombard (Health)', { workbook: 'Health Insurance (2).xlsx' });
addPolicy('ICICI Lombard', 'Travel', 'ICICI Lombard Travel Insurance', 'ICICI-TRAVEL', [pct('Travel insurance', 30)], 'ICICI Lombard (Health)', { workbook: 'Health Insurance (2).xlsx' });
addPolicy('ICICI Lombard', 'Home', 'ICICI Lombard Home Insurance', 'ICICI-HOME', [pct('Home insurance', 30)], 'ICICI Lombard (Health)', { workbook: 'Health Insurance (2).xlsx' });
addPolicy('Care Health', 'Health', 'Care Health Portfolio', 'CARE-HLTH', [band('Below Rs 500,000', 0, 499999, 35), band('Rs 500,000 and above', 500000, null, 40)], 'Care', { workbook: 'Health Insurance (2).xlsx' });
addPolicy('HDFC ERGO', 'Health', 'HDFC ERGO Health Portfolio', 'HDFC-HLTH', [
  band('Rs 10 lakh to below Rs 15 lakh sum insured', 1000000, 1499999, 20, 'sumInsured'),
  band('Rs 15 lakh and above sum insured', 1500000, null, 25, 'sumInsured'),
  band('Rs 10-15 lakh with Rs 25k deductible, fresh or port', 1000000, 1499999, 25, 'sumInsured', { conditions: { deductible: '25000' } }),
  band('Rs 15 lakh+ with Rs 25k deductible, fresh or port', 1500000, null, 31, 'sumInsured', { conditions: { deductible: '25000' } }),
], 'HDFC ERGO(Health)', { workbook: 'Health Insurance (2).xlsx' });
addPolicy('Star Health', 'Health', 'Star Health New Business', 'STAR-NEW', [
  band('Up to Rs 100,000 monthly GWP', 0, 100000, 20, 'monthlyBusiness'), band('Rs 100,000 to 200,000', 100000, 200000, 25, 'monthlyBusiness'),
  band('Rs 300,000 to 500,000', 300000, 500000, 30, 'monthlyBusiness'), band('Rs 500,000 to 750,000', 500000, 750000, 35, 'monthlyBusiness'),
  band('Rs 750,000 to 1,000,000', 750000, 1000000, 37.5, 'monthlyBusiness'), band('Above Rs 1,000,000', 1000001, null, 40, 'monthlyBusiness'),
], 'Star', { workbook: 'Health Insurance (2).xlsx', renewalCommission: 15, raw: 'New/Renewal: up to 1L 20/15; 1-2L 25/15; 3-5L 30/18; 5-7.5L 35/20; 7.5-10L 37.5/21; above 10L 40/21.' });
addPolicy('Star Health', 'Travel', 'Star Travel Business', 'STAR-TRAVEL', [
  band('Up to Rs 25,000 monthly GWP, age <=65', 0, 25000, 35, 'monthlyBusiness', { conditions: { ageBand: 'Up to 65' } }),
  band('Rs 25,000 to 50,000, age <=65', 25000, 50000, 40, 'monthlyBusiness', { conditions: { ageBand: 'Up to 65' } }),
  band('Rs 50,000 to 100,000, age <=65', 50000, 100000, 42.5, 'monthlyBusiness', { conditions: { ageBand: 'Up to 65' } }),
  band('Rs 100,000 to 200,000, age <=65', 100000, 200000, 45, 'monthlyBusiness', { conditions: { ageBand: 'Up to 65' } }),
  band('Rs 200,000 to 300,000, age <=65', 200000, 300000, 47.5, 'monthlyBusiness', { conditions: { ageBand: 'Up to 65' } }),
  band('Rs 300,000 to 500,000, age <=65', 300000, 500000, 50, 'monthlyBusiness', { conditions: { ageBand: 'Up to 65' } }),
  band('Above Rs 500,000, age <=65', 500001, null, 55, 'monthlyBusiness', { conditions: { ageBand: 'Up to 65' } }),
  pct('Above age 65', 35, { conditions: { ageBand: 'Above 65' } }),
], 'Star', { workbook: 'Health Insurance (2).xlsx' });
for (const [name, rate] of [['Employer Employee', 20], ['Group Micro Insurance', 45], ['Benefit Products Top-up', 55], ['Other Group Products', 20]]) addPolicy('Star Health', 'Group', name, `STAR-${slug(name).toUpperCase()}`, [pct(name, rate)], 'Star', { workbook: 'Health Insurance (2).xlsx' });
addPolicy('Galaxy Health', 'Health', 'Galaxy Indemnity Products', 'GALAXY-INDEMNITY', [pct('Indemnity products flat', 40)], 'Galaxy', { workbook: 'Health Insurance (2).xlsx' });
addPolicy('Galaxy Health', 'Health', 'Galaxy Benefit Top-up Products', 'GALAXY-TOPUP', [pct('Benefit products top-up maximum', 55)], 'Galaxy', { workbook: 'Health Insurance (2).xlsx', renewalCommission: 15, raw: 'Benefit Products (Topup) up to 55%. Volume top-up: <=1L 15%; 1-3L 15%; 3-5L 20%; 5-7.5L 25%; 7.5-10L 27%; 10L+ 30%.' });
addPolicy('Galaxy Health', 'Health', 'Galaxy Monthly Volume Portfolio', 'GALAXY-VOLUME', [
  band('Up to Rs 100,000', 0, 100000, 20, 'monthlyBusiness'), band('Rs 100,000 to 300,000', 100000, 300000, 25, 'monthlyBusiness'),
  band('Rs 300,000 to 500,000', 300000, 500000, 30, 'monthlyBusiness'), band('Rs 500,000 to 750,000', 500000, 750000, 35, 'monthlyBusiness'),
  band('Rs 750,000 to 1,000,000', 750000, 1000000, 37.5, 'monthlyBusiness'), band('Rs 1,000,000 and above', 1000000, null, 40, 'monthlyBusiness'),
  pct('Portable business', 15, { conditions: { businessType: 'Port' } }),
], 'Galaxy', { workbook: 'Health Insurance (2).xlsx', renewalCommission: 15 });
addPolicy('ManipalCigna', 'Health', 'ManipalCigna Health Portfolio', 'MANIPALCIGNA-HLTH', [
  band('Below Rs 225,000', 0, 224999, 15, 'monthlyBusiness'), band('Rs 225,000 to 374,999', 225000, 374999, 20, 'monthlyBusiness'),
  band('Rs 375,000 to 599,999', 375000, 599999, 25, 'monthlyBusiness'), band('Rs 600,000 to 1,199,999', 600000, 1199999, 27.5, 'monthlyBusiness'),
  band('Rs 1,200,000 to 1,799,999', 1200000, 1799999, 30, 'monthlyBusiness'), band('Rs 1,800,000 to 2,999,999', 1800000, 2999999, 35, 'monthlyBusiness'),
  band('Rs 3,000,000 and above', 3000000, null, 40, 'monthlyBusiness'), pct('Port flat', 30, { conditions: { businessType: 'Port' } }),
], 'ManipalCigna', { workbook: 'Health Insurance (2).xlsx', raw: 'Monthly slabs 15%-40%; Port flat 30%; Elite Club max 40%; CDO Club +7%; HOH Club +7%; FY target Apr 2026-Mar 2027 Rs 1.25 Cr.' });

// Life workbook.
for (const [name, rate] of [['Term Plan', 40], ['ACE Traditional', 35], ['Invest Protect Goal', 15], ['ULIP', 9], ['Goal Suraksha', 20]]) addPolicy('Bajaj Allianz Life', 'Life', name, `BAJAJ-LIFE-${slug(name).toUpperCase()}`, [pct(name, rate)], 'BAJAJ LIFE', { workbook: 'Life Insuranco Companies (7).xlsx', raw: `${name}: ${rate}%. Performance bonus on base: 0-1.5L +10%; 1.5-3L +20%; 3-5L +30%; 5-7.5L +40%; 7.5-12L+ +50%. HPB: 20-25L +30%; 25-30L +35%; 30-40L +40%; 40L+ +50%.` });
addPolicy('ICICI Prudential Life', 'Life', 'Term Plan', 'ICICI-PRU-TERM', [pct('Term Plan', 40)], 'ICICI Pru Life', { workbook: 'Life Insuranco Companies (7).xlsx' });
addPolicy('ICICI Prudential Life', 'Life', 'Protect and Gain Plan', 'ICICI-PRU-PROTECT-GAIN', [pct('Term rate multiplied three times', 0, { baseMultiplier: 3 })], 'ICICI Pru Life', { workbook: 'Life Insuranco Companies (7).xlsx', raw: 'Protect & Gain Plan: Term commission x 3.' });
addPolicy('ICICI Prudential Life', 'Life', 'ULIP', 'ICICI-PRU-ULIP', [pct('ULIP', 6)], 'ICICI Pru Life', { workbook: 'Life Insuranco Companies (7).xlsx' });
addPolicy('ICICI Prudential Life', 'Life', 'Traditional Plan', 'ICICI-PRU-TRADITIONAL', [{ label: 'PPT x 4', metric: 'ppt', termMultiplier: 4 }], 'ICICI Pru Life', { workbook: 'Life Insuranco Companies (7).xlsx' });
const absli = [['Super Term', 30], ['Sampoorna Suraksha Kavach', 40]];
for (const [name, rate] of absli) addPolicy('Aditya Birla Sun Life', 'Life', name, `ABSLI-${slug(name).toUpperCase()}`, [pct(name, rate)], 'Aditya Birla Sun Life', { workbook: 'Life Insuranco Companies (7).xlsx' });
for (const [name, rates] of [['Nischit Ayush', [[10,30],[12,35]]], ['Assured Savings Plan', [[10,25],[12,30]]], ['Non Guaranteed Plans', [[10,30],[12,35]]]]) addPolicy('Aditya Birla Sun Life', 'Life', name, `ABSLI-${slug(name).toUpperCase()}`, rates.map(([pptValue, rate]) => band(`PPT ${pptValue}`, pptValue, pptValue, rate, 'ppt')), 'Aditya Birla Sun Life', { workbook: 'Life Insuranco Companies (7).xlsx' });
addPolicy('Aditya Birla Sun Life', 'Life', 'ABSLI GAP Plan', 'ABSLI-GAP', [band('Single Pay', 1, 1, 2, 'ppt'), band('2-3 Pay', 2, 3, 10, 'ppt'), band('5 PPT', 5, 5, 15, 'ppt'), band('6 PPT', 6, 6, 18, 'ppt')], 'Aditya Birla Sun Life', { workbook: 'Life Insuranco Companies (7).xlsx', raw: 'Monthly and quarterly performance slabs apply in addition: monthly 1-2.5L +25%, 2.5-5L +75%, 5-10L +80%, 10L+ +85%; quarterly 7.5-15L +20%, 15-30L +25%, 30L+ +35% on base.' });
addPolicy('Axis Max Life', 'Life', 'Term and Endowment Plans', 'AXIS-MAX-TERM-ENDOWMENT', [{ label: 'PPT x 3, capped at 35%', metric: 'ppt', termMultiplier: 3, maxPercent: 35 }], 'Axis Max Life', { workbook: 'Life Insuranco Companies (7).xlsx', raw: 'Base commission PPT x3 or max 35%. Annual business bonus on base: <3L 0%; 3-5.99999L +50%; 6-9.99999L +60%; 10-19.99999L +70%; 20-29.99999L +80%; 30-39.99999L +90%; 40-49.99999L +100%; 50L+ +120%.' });
addPolicy('Axis Max Life', 'Life', 'Non-Par Guaranteed Savings', 'AXIS-MAX-NONPAR', [{ label: 'PPT x 2, capped at 35%', metric: 'ppt', termMultiplier: 2, maxPercent: 35 }], 'Axis Max Life', { workbook: 'Life Insuranco Companies (7).xlsx' });
addPolicy('Axis Max Life', 'Life', 'ULIP', 'AXIS-MAX-ULIP', [pct('ULIP base commission', 7)], 'Axis Max Life', { workbook: 'Life Insuranco Companies (7).xlsx' });
addPolicy('Axis Max Life', 'Life', 'Star ULIP', 'AXIS-MAX-STAR-ULIP', [band('PPT 5',5,5,45,'ppt'),band('PPT 7',7,7,47,'ppt'),band('PPT 10',10,10,49,'ppt')], 'Axis Max Life', { workbook: 'Life Insuranco Companies (7).xlsx' });
addPolicy('Axis Max Life', 'Life', 'Pension Plans', 'AXIS-MAX-PENSION', [{ label: 'PPT x 2', metric: 'ppt', termMultiplier: 2 }], 'Axis Max Life', { workbook: 'Life Insuranco Companies (7).xlsx' });
const sbiLife = [
  ['Term','Smart Shield Premier',[[5,9,15],[10,29,25],[30,null,30]],5], ['Term','Smart Shield Plus',[[5,9,15],[10,29,25],[30,null,30]],5],
  ['Term','Saral Jeevan Bima',[[5,9,20],[10,14,30],[15,null,35]],5], ['TROP','Saral Swadhan Supreme',[[7,7,21],[10,10,30]],5],
  ['TROP','Smart Swadhan Supreme',[[7,7,21],[10,10,30]],5], ['TROP','Smart Swadhan Neo',[[7,15,15]],7.5],
  ['ULIP','Smart Fortune Builder',[[0,null,10]],2], ['ULIP','Smart Elite Plus Single Premium',[[1,1,2]],0], ['ULIP','Smart Elite Plus',[[7,21,2.5]],2.5],
  ['ULIP','Smart Scholar Plus',[[0,null,5.5]],3], ['ULIP','Retire Plans',[[15,15,7.5]],2],
  ['Non Par','New Smart Samriddhi',[[6,6,18],[7,7,21],[10,10,30]],4], ['Non Par','Smart Platina Plus and Supreme',[[7,7,21],[8,8,24],[10,10,30]],4],
  ['Non Par','Smart Platina Advantage',[[7,7,21],[10,10,30]],4], ['Non Par','Smart Platina Young Achiever',[[7,7,21],[10,10,30]],4],
  ['PAR','Life Time Saver',[[10,10,30],[12,12,35],[15,15,35]],7.5], ['PAR','Smart Bachat Plus',[[7,7,21],[10,10,30],[15,15,35]],7.5],
  ['PAR','Smart Future Star',[[7,7,21],[10,10,30],[15,15,35]],7.5], ['PAR','Smart Money Back Plus',[[7,7,21],[10,10,30],[12,12,35]],7.5],
];
for (const [section,name,rates,renewal] of sbiLife) addPolicy('SBI Life', 'Life', name, `SBI-LIFE-${slug(name).toUpperCase()}`, rates.map(([from,to,rate]) => band(`${from || 'Any'}${to ? `-${to}` : '+'} PPT`,from,to,rate,'ppt')), 'SBI Life ', { workbook: 'Life Insuranco Companies (7).xlsx', renewalCommission: renewal, policySection: section });

// General workbook: one policy record per insurer department, with every workbook line retained and structured rates where unambiguous.
addPolicy('IFFCO Tokio', 'Motor', 'IFFCO Tokio Full and Commercial Vehicle', 'IFFCO-MOTOR-VOLUME', [band('0-50,000 monthly',0,50000,15,'monthlyBusiness'),band('50,000-99,999 monthly',50000,99999,20,'monthlyBusiness'),band('100,000-299,999 monthly',100000,299999,22.5,'monthlyBusiness'),band('300,000-699,999 monthly',300000,699999,24,'monthlyBusiness'),band('700,000-999,999 monthly',700000,999999,26,'monthlyBusiness'),band('1,000,000+ monthly',1000000,null,30,'monthlyBusiness')], 'IFFCO TOKIO', { workbook: 'General Insurance (5).xlsx', raw: 'Full/commercial monthly: 0-50k 15%; 50k-99999 20%; 1-299999L 22.5%; 3-699999L 24%; 7-999999L 26%; 10L+ 30%. Surety bonds max 30%; TPA commercial 32.5%; private car TPA 2.5%; 2-wheelers 2.5%; comprehensive 28%; non-motor except GMC/GPA 15%.' });
addPolicy('SBI General', 'Motor', 'SBI General Motor Portfolio', 'SBI-MOTOR-PORTFOLIO', [pct('Private car comprehensive / SAOD other than high end',28),pct('Private car comprehensive / SAOD',25),pct('Tractors and harvesters new',42),pct('Tractors and harvesters SATP',45),pct('School bus comprehensive',55),pct('School bus SATP',57),pct('2-wheeler scooter up to 150cc',35),pct('2-wheeler bike up to 125cc',23.5)], 'SBI Motor', { workbook: 'General Insurance (5).xlsx', raw: 'Workbook contains vehicle/tonnage/age-specific rates from 7% to 60%, including GCV, PCV, taxis, tractors, harvesters, school buses, private cars and two-wheelers. Exact source rows are retained in the source workbook; primary structured variants are stored in commissionRules.' });
addPolicy('Bajaj Allianz General', 'General', 'Bajaj General Monthly Portfolio', 'BAJAJ-GENERAL-VOLUME', [band('0-9,999',0,9999,15,'monthlyBusiness'),band('10,000-24,999',10000,24999,17.5,'monthlyBusiness'),band('25,000-49,999',25000,49999,20,'monthlyBusiness'),band('50,000-74,999',50000,74999,22.5,'monthlyBusiness'),band('75,000-99,999',75000,99999,25,'monthlyBusiness'),band('100,000-199,999',100000,199999,30,'monthlyBusiness'),band('200,000-499,999',200000,499999,32.5,'monthlyBusiness'),band('500,000+',500000,null,35,'monthlyBusiness')], 'Bajaj', { workbook: 'General Insurance (5).xlsx', raw: 'Monthly slabs 15%-35%; TPA 4-wheeler 15%; Surety bonds max 12.5%.' });
addPolicy('HDFC ERGO', 'Travel', 'HDFC ERGO Travel Insurance', 'HDFC-TRAVEL', [pct('Travel insurance',40)], 'HDFC ERGO', { workbook: 'General Insurance (5).xlsx' });
addPolicy('HDFC ERGO', 'General', 'HDFC ERGO Personal Accident Insurance', 'HDFC-PAI', [pct('PAI',28)], 'HDFC ERGO', { workbook: 'General Insurance (5).xlsx' });
addPolicy('HDFC ERGO', 'Motor', 'HDFC ERGO Motor Zone Portfolio', 'HDFC-MOTOR-ZONES', [band('Zone 1 package below 10k',0,9999,17.5),band('Zone 1 package 10k-50k',10000,50000,19.5),band('Zone 1 package 50k-1L',50001,100000,21),band('Zone 1 package 1L-2L',100001,200000,23),band('Zone 1 package above 2L',200001,null,25)], 'HDFC ERGO', { workbook: 'General Insurance (5).xlsx', raw: 'Motor rates include Zone 1 and Zone 2 matrices for petrol/non-petrol Package, NCB, non-NCB and SAOD from 10% to 25%. All commissions are paid after GST and TDS deductions.' });
for (const [name, rate] of [['Contractor All Risk Policy',25],['Fire',15],['GMC/GPA',7.5],['Warehouse',15],['Marine',15],['Surety Bonds',15],['Truck 12-20 Ton AP OD and TP',32],['Truck 40 Ton AP OD and TP',25],['3W PCV OD and TP',60],['SCV above 2 Ton',60],['LCV 7.5-12 Ton Comprehensive',35],['Private Car New and NCB',25],['Private Car Non-NCB',15],['Private Car Used',25]]) addPolicy('ICICI Lombard', name.includes('Truck')||name.includes('PCV')||name.includes('SCV')||name.includes('LCV')||name.includes('Car')?'Motor':'General', name, `ICICI-${slug(name).toUpperCase()}`, [pct(name,rate)], 'ICICI Lombard', { workbook: 'General Insurance (5).xlsx', raw: name === 'Contractor All Risk Policy' ? '25%-30% depending on premium.' : undefined });
for (const [dept,name,rate] of [['Motor','2-Wheeler up to 150cc',27.5],['Motor','2-Wheeler 150-350cc',22.5],['Motor','2-Wheeler above 350cc',17.5],['Motor','Electric Vehicles',22.5],['Motor','Private Car Package',20],['Motor','Private Car Standalone OD',12],['Motor','Private Car Standalone TP',20],['Marine','Marine Cargo',20],['Marine','Marine Hull',20]]) addPolicy('United India',dept,name,`UIIC-${slug(name).toUpperCase()}`,[pct(name,rate)],'United India',{workbook:'General Insurance (5).xlsx'});
addPolicy('New India Assurance', 'Health', 'New India Health Plans', 'NIA-HEALTH', [band('Age below 40',0,39,40,'age'),band('Age 40-55',40,55,27,'age'),band('Age 55 and above',55,null,15,'age')], 'New India Assurance', { workbook:'General Insurance (5).xlsx', renewalCommission:15, raw:'New business/renewal: age <40 40/20%; age 40-55 27/20%; age 55+ 15/15%.' });
for (const [dept,name,rate] of [['Health','Group Mediclaim Employer Employee',7.5],['Health','Group Mediclaim Other Groups',15],['Health','Group Mediclaim Credit Linked',15],['General','Fire Large Risk',15],['General','Fire Standalone War',6.25],['Engineering','Engineering Annual Policies',20],['Engineering','Project Policies TSI up to Rs 2,500 Cr',12.5],['Engineering','Other Project Policies',25],['Rural','Rural/Credit/Surety Bonds',15],['Motor','School Bus OD and TP',60]]) addPolicy('New India Assurance',dept,name,`NIA-${slug(name).toUpperCase()}`,[pct(name,rate)],'New India Assurance',{workbook:'General Insurance (5).xlsx'});

function value(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(value) } };
  return { mapValue: { fields: fields(v) } };
}
function fields(obj) { return Object.fromEntries(Object.entries(obj).map(([k,v]) => [k,value(v)])); }
async function put(collection, id, data, token) {
  const response = await fetch(`${base}/${collection}/${id}`, { method:'PATCH', headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'}, body:JSON.stringify({fields:fields(data)}) });
  if (!response.ok) throw new Error(`${collection}/${id}: ${response.status} ${await response.text()}`);
}
const token = execFileSync('cmd.exe', ['/d','/s','/c','gcloud auth print-access-token'], { encoding:'utf8' }).trim();
for (const c of companies) await put('insurance_companies', c.id, { ...c, createdAt: importedAt, updatedAt: importedAt }, token);
for (const c of companies) for (const departmentName of c.departments) await put('insurance_departments', `${c.id}-${slug(departmentName)}`, { companyId:c.id, companyName:c.companyName, departmentName, status:'Active', createdAt:importedAt, updatedAt:importedAt }, token);
for (const p of policies) {
  const collection = p.category === 'Life' ? 'life_policies' : p.category === 'Health' || p.departmentName === 'Travel' || p.departmentName === 'Home' || p.departmentName === 'Group' ? 'policies' : 'general_policies';
  const legacy = p.category === 'Life' ? { lifeCommissions: [] } : collection === 'policies' ? { healthCommissions: [] } : { generalCommissions: [{ type:'premium', slabs:p.commissionRules.filter((r) => r.percent != null).map((r) => ({ label:r.label, percent:r.percent })) }] };
  await put(collection, p.id, { ...p, ...legacy, createdAt:importedAt, updatedAt:importedAt }, token);
}
console.log(JSON.stringify({ project, companies:companies.length, departments:companies.reduce((n,c)=>n+c.departments.length,0), policies:policies.length, byCollection:{ policies:policies.filter((p)=>!['Life'].includes(p.category) && (p.category==='Health'||['Travel','Home','Group'].includes(p.departmentName))).length, life_policies:policies.filter((p)=>p.category==='Life').length, general_policies:policies.filter((p)=>p.category!=='Life' && p.category!=='Health' && !['Travel','Home','Group'].includes(p.departmentName)).length } }, null, 2));
