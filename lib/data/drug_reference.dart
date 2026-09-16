/// A local, offline reference of well-known/common medicines and what
/// they're generally used for — NOT a complete world drug database
/// (that doesn't practically exist), and NOT a substitute for
/// professional medical judgment. It exists to save typing for the
/// most common generics and widely-known brand names a general
/// pharmacy is likely to carry.
///
/// Each entry: generic/brand English name, Arabic name, and a short
/// Arabic description of its general use (drug class level — not
/// dosing, not rare/off-label uses).
class DrugReference {
  const DrugReference({required this.nameEn, required this.nameAr, required this.treatsAr});
  final String nameEn;
  final String nameAr;
  final String treatsAr;
}

const List<DrugReference> drugDatabase = [
  // ---- Analgesics / antipyretics ----
  DrugReference(nameEn: 'Paracetamol / Acetaminophen', nameAr: 'باراسيتامول', treatsAr: 'خافض حرارة ومسكن للألم البسيط والمتوسط — صداع، حمى، آلام عامة'),
  DrugReference(nameEn: 'Panadol', nameAr: 'بانادول', treatsAr: 'خافض حرارة ومسكن للألم (باراسيتامول) — صداع، حمى، آلام عامة'),
  DrugReference(nameEn: 'Fevadol', nameAr: 'فيفادول', treatsAr: 'خافض حرارة ومسكن للألم (باراسيتامول) — صداع، حمى'),
  DrugReference(nameEn: 'Adol', nameAr: 'أدول', treatsAr: 'خافض حرارة ومسكن للألم (باراسيتامول) — صداع، حمى'),
  DrugReference(nameEn: 'Ibuprofen', nameAr: 'إيبوبروفين', treatsAr: 'مسكن ومضاد التهاب وخافض حرارة — آلام، التهابات، حمى'),
  DrugReference(nameEn: 'Brufen', nameAr: 'بروفين', treatsAr: 'مسكن ومضاد التهاب (إيبوبروفين) — آلام، حمى'),
  DrugReference(nameEn: 'Aspirin', nameAr: 'أسبرين', treatsAr: 'مسكن وخافض حرارة، وبجرعة منخفضة يستخدم لتمييع الدم والوقاية القلبية'),
  DrugReference(nameEn: 'Diclofenac', nameAr: 'ديكلوفيناك', treatsAr: 'مضاد التهاب ومسكن للألم — آلام المفاصل والعضلات'),
  DrugReference(nameEn: 'Cataflam', nameAr: 'كتافلام', treatsAr: 'مضاد التهاب ومسكن (ديكلوفيناك بوتاسيوم) — آلام حادة'),
  DrugReference(nameEn: 'Voltaren', nameAr: 'فولتارين', treatsAr: 'مضاد التهاب ومسكن موضعي أو فموي (ديكلوفيناك)'),
  DrugReference(nameEn: 'Naproxen', nameAr: 'نابروكسين', treatsAr: 'مضاد التهاب ومسكن للألم طويل المفعول'),
  DrugReference(nameEn: 'Mefenamic Acid', nameAr: 'مفينامك أسيد', treatsAr: 'مسكن للألم، يستخدم كثيراً لآلام الدورة الشهرية'),
  DrugReference(nameEn: 'Tramadol', nameAr: 'ترامادول', treatsAr: 'مسكن قوي للألم المتوسط إلى الشديد'),

  // ---- Antibiotics ----
  DrugReference(nameEn: 'Amoxicillin', nameAr: 'أموكسيسيلين', treatsAr: 'مضاد حيوي واسع الطيف — التهابات الجهاز التنفسي والأذن والحلق'),
  DrugReference(nameEn: 'Augmentin (Amoxicillin-Clavulanate)', nameAr: 'أوغمنتين', treatsAr: 'مضاد حيوي معزز — التهابات بكتيرية متنوعة مقاومة'),
  DrugReference(nameEn: 'Azithromycin', nameAr: 'أزيثرومايسين', treatsAr: 'مضاد حيوي — التهابات الجهاز التنفسي والحلق، جرعة قصيرة'),
  DrugReference(nameEn: 'Zithromax', nameAr: 'زيثروماكس', treatsAr: 'مضاد حيوي (أزيثرومايسين) — التهابات تنفسية'),
  DrugReference(nameEn: 'Ciprofloxacin', nameAr: 'سيبروفلوكساسين', treatsAr: 'مضاد حيوي — التهابات المسالك البولية والجهاز الهضمي'),
  DrugReference(nameEn: 'Levofloxacin', nameAr: 'ليفوفلوكساسين', treatsAr: 'مضاد حيوي واسع الطيف — التهابات تنفسية وبولية'),
  DrugReference(nameEn: 'Doxycycline', nameAr: 'دوكسيسايكلين', treatsAr: 'مضاد حيوي — حب الشباب، التهابات تنفسية وجلدية'),
  DrugReference(nameEn: 'Cephalexin', nameAr: 'سيفاليكسين', treatsAr: 'مضاد حيوي — التهابات الجلد والمسالك البولية والتنفسية'),
  DrugReference(nameEn: 'Ceftriaxone', nameAr: 'سيفترياكسون', treatsAr: 'مضاد حيوي بالحقن — التهابات بكتيرية شديدة'),
  DrugReference(nameEn: 'Metronidazole', nameAr: 'ميترونيدازول', treatsAr: 'مضاد حيوي وطفيليات — التهابات معوية ونسائية وأسنان'),
  DrugReference(nameEn: 'Flagyl', nameAr: 'فلاجيل', treatsAr: 'مضاد حيوي وطفيليات (ميترونيدازول)'),
  DrugReference(nameEn: 'Clindamycin', nameAr: 'كليندامايسين', treatsAr: 'مضاد حيوي — التهابات جلدية وأسنان وعظام'),
  DrugReference(nameEn: 'Erythromycin', nameAr: 'إريثرومايسين', treatsAr: 'مضاد حيوي بديل للبنسلين — التهابات تنفسية وجلدية'),
  DrugReference(nameEn: 'Trimethoprim-Sulfamethoxazole', nameAr: 'كوتريموكسازول', treatsAr: 'مضاد حيوي — التهابات المسالك البولية والتنفسية'),
  DrugReference(nameEn: 'Nitrofurantoin', nameAr: 'نيتروفورانتوين', treatsAr: 'مضاد حيوي مخصص لالتهابات المسالك البولية'),

  // ---- Antifungals ----
  DrugReference(nameEn: 'Fluconazole', nameAr: 'فلوكونازول', treatsAr: 'مضاد فطريات — عدوى الخميرة والفطريات الفموية والمهبلية'),
  DrugReference(nameEn: 'Clotrimazole', nameAr: 'كلوتريمازول', treatsAr: 'مضاد فطريات موضعي — فطريات الجلد والمهبل'),
  DrugReference(nameEn: 'Ketoconazole', nameAr: 'كيتوكونازول', treatsAr: 'مضاد فطريات — فطريات الجلد وقشرة الرأس'),
  DrugReference(nameEn: 'Nystatin', nameAr: 'نيستاتين', treatsAr: 'مضاد فطريات — فطريات فموية ومعوية'),
  DrugReference(nameEn: 'Terbinafine', nameAr: 'تيربينافين', treatsAr: 'مضاد فطريات — فطريات الأظافر والجلد'),

  // ---- Antivirals ----
  DrugReference(nameEn: 'Acyclovir', nameAr: 'أسيكلوفير', treatsAr: 'مضاد فيروسات — الهربس وقروح البرد'),
  DrugReference(nameEn: 'Oseltamivir (Tamiflu)', nameAr: 'تاميفلو', treatsAr: 'مضاد فيروسات — الإنفلونزا'),

  // ---- Antihistamines / allergy ----
  DrugReference(nameEn: 'Cetirizine', nameAr: 'سيتريزين', treatsAr: 'مضاد حساسية — حساسية الأنف والجلد والحكة'),
  DrugReference(nameEn: 'Loratadine', nameAr: 'لوراتادين', treatsAr: 'مضاد حساسية غير منوّم — حساسية موسمية'),
  DrugReference(nameEn: 'Fexofenadine', nameAr: 'فيكسوفينادين', treatsAr: 'مضاد حساسية غير منوّم — حساسية الأنف والجلد'),
  DrugReference(nameEn: 'Desloratadine', nameAr: 'ديسلوراتادين', treatsAr: 'مضاد حساسية — حساسية موسمية وشرى جلدي'),
  DrugReference(nameEn: 'Chlorpheniramine', nameAr: 'كلورفينيرامين', treatsAr: 'مضاد حساسية منوّم — نزلات البرد والحساسية'),
  DrugReference(nameEn: 'Diphenhydramine', nameAr: 'دايفينهيدرامين', treatsAr: 'مضاد حساسية منوّم — حساسية، دوار السفر، أرق مؤقت'),

  // ---- GI / digestive ----
  DrugReference(nameEn: 'Omeprazole', nameAr: 'أوميبرازول', treatsAr: 'مثبط لحموضة المعدة — قرحة، ارتجاع مريئي، حرقة'),
  DrugReference(nameEn: 'Esomeprazole', nameAr: 'إيزوميبرازول', treatsAr: 'مثبط لحموضة المعدة — ارتجاع وقرحة'),
  DrugReference(nameEn: 'Nexium', nameAr: 'نيكسيوم', treatsAr: 'مثبط لحموضة المعدة (إيزوميبرازول)'),
  DrugReference(nameEn: 'Pantoprazole', nameAr: 'بانتوبرازول', treatsAr: 'مثبط لحموضة المعدة — ارتجاع وقرحة'),
  DrugReference(nameEn: 'Ranitidine', nameAr: 'رانيتيدين', treatsAr: 'مضاد للحموضة — حرقة المعدة وقرحة'),
  DrugReference(nameEn: 'Domperidone', nameAr: 'دومبيريدون', treatsAr: 'منظم لحركة المعدة — غثيان، انتفاخ، بطء الهضم'),
  DrugReference(nameEn: 'Motilium', nameAr: 'موتيليوم', treatsAr: 'منظم لحركة المعدة (دومبيريدون)'),
  DrugReference(nameEn: 'Metoclopramide', nameAr: 'ميتوكلوبراميد', treatsAr: 'مضاد غثيان ومنظم لحركة المعدة'),
  DrugReference(nameEn: 'Loperamide', nameAr: 'لوبيراميد', treatsAr: 'مضاد للإسهال'),
  DrugReference(nameEn: 'Oral Rehydration Salts (ORS)', nameAr: 'أملاح الإماهة الفموية', treatsAr: 'تعويض السوائل والأملاح — إسهال وجفاف'),
  DrugReference(nameEn: 'Lactulose', nameAr: 'لاكتيولوز', treatsAr: 'ملين — علاج الإمساك'),
  DrugReference(nameEn: 'Simethicone', nameAr: 'سيميثيكون', treatsAr: 'مضاد للانتفاخ والغازات'),
  DrugReference(nameEn: 'Mebeverine', nameAr: 'ميبيفيرين', treatsAr: 'مضاد تشنج للأمعاء — القولون العصبي'),
  DrugReference(nameEn: 'Hyoscine (Buscopan)', nameAr: 'بوسكوبان', treatsAr: 'مضاد تشنج — مغص وآلام البطن'),

  // ---- Cardiovascular ----
  DrugReference(nameEn: 'Amlodipine', nameAr: 'أملوديبين', treatsAr: 'خافض لضغط الدم — ارتفاع ضغط الدم'),
  DrugReference(nameEn: 'Norvasc', nameAr: 'نورفاسك', treatsAr: 'خافض لضغط الدم (أملوديبين)'),
  DrugReference(nameEn: 'Atenolol', nameAr: 'أتينولول', treatsAr: 'خافض لضغط الدم ومنظم لضربات القلب'),
  DrugReference(nameEn: 'Bisoprolol', nameAr: 'بيسوبرولول', treatsAr: 'خافض لضغط الدم وأمراض القلب'),
  DrugReference(nameEn: 'Concor', nameAr: 'كونكور', treatsAr: 'خافض لضغط الدم (بيسوبرولول)'),
  DrugReference(nameEn: 'Losartan', nameAr: 'لوسارتان', treatsAr: 'خافض لضغط الدم'),
  DrugReference(nameEn: 'Valsartan', nameAr: 'فالسارتان', treatsAr: 'خافض لضغط الدم وحماية القلب'),
  DrugReference(nameEn: 'Enalapril', nameAr: 'إينالابريل', treatsAr: 'خافض لضغط الدم'),
  DrugReference(nameEn: 'Lisinopril', nameAr: 'ليسينوبريل', treatsAr: 'خافض لضغط الدم وحماية القلب'),
  DrugReference(nameEn: 'Furosemide', nameAr: 'فوروسيمايد', treatsAr: 'مدر للبول — احتباس السوائل وضغط الدم'),
  DrugReference(nameEn: 'Lasix', nameAr: 'لازيكس', treatsAr: 'مدر للبول (فوروسيمايد)'),
  DrugReference(nameEn: 'Hydrochlorothiazide', nameAr: 'هيدروكلوروثيازايد', treatsAr: 'مدر للبول وخافض لضغط الدم'),
  DrugReference(nameEn: 'Spironolactone', nameAr: 'سبيرونولاكتون', treatsAr: 'مدر للبول موفر للبوتاسيوم'),
  DrugReference(nameEn: 'Atorvastatin', nameAr: 'أتورفاستاتين', treatsAr: 'خافض للكولسترول والدهون'),
  DrugReference(nameEn: 'Lipitor', nameAr: 'ليبيتور', treatsAr: 'خافض للكولسترول (أتورفاستاتين)'),
  DrugReference(nameEn: 'Rosuvastatin', nameAr: 'روزوفاستاتين', treatsAr: 'خافض للكولسترول والدهون'),
  DrugReference(nameEn: 'Crestor', nameAr: 'كريستور', treatsAr: 'خافض للكولسترول (روزوفاستاتين)'),
  DrugReference(nameEn: 'Simvastatin', nameAr: 'سيمفاستاتين', treatsAr: 'خافض للكولسترول'),
  DrugReference(nameEn: 'Clopidogrel', nameAr: 'كلوبيدوجريل', treatsAr: 'مميع للدم — وقاية من الجلطات'),
  DrugReference(nameEn: 'Plavix', nameAr: 'بلافيكس', treatsAr: 'مميع للدم (كلوبيدوجريل)'),
  DrugReference(nameEn: 'Warfarin', nameAr: 'وارفارين', treatsAr: 'مميع للدم — وقاية من الجلطات'),
  DrugReference(nameEn: 'Digoxin', nameAr: 'ديجوكسين', treatsAr: 'منظم لضربات القلب وقوة انقباضه'),
  DrugReference(nameEn: 'Nitroglycerin', nameAr: 'نيتروجليسرين', treatsAr: 'موسع للشرايين — الذبحة الصدرية'),
  DrugReference(nameEn: 'Isosorbide Dinitrate', nameAr: 'إيزوسوربيد دينيترات', treatsAr: 'موسع للشرايين — الذبحة الصدرية'),
  DrugReference(nameEn: 'Enoxaparin (Clexane)', nameAr: 'كليكسان', treatsAr: 'مميع للدم بالحقن — وقاية من الجلطات'),

  // ---- Diabetes ----
  DrugReference(nameEn: 'Metformin', nameAr: 'ميتفورمين', treatsAr: 'خافض لسكر الدم — النوع الثاني من السكري'),
  DrugReference(nameEn: 'Glucophage', nameAr: 'جلوكوفاج', treatsAr: 'خافض لسكر الدم (ميتفورمين)'),
  DrugReference(nameEn: 'Glimepiride', nameAr: 'جليميبيرايد', treatsAr: 'خافض لسكر الدم'),
  DrugReference(nameEn: 'Amaryl', nameAr: 'أماريل', treatsAr: 'خافض لسكر الدم (جليميبيرايد)'),
  DrugReference(nameEn: 'Gliclazide', nameAr: 'جليكلازايد', treatsAr: 'خافض لسكر الدم'),
  DrugReference(nameEn: 'Diamicron', nameAr: 'ديامكرون', treatsAr: 'خافض لسكر الدم (جليكلازايد)'),
  DrugReference(nameEn: 'Sitagliptin', nameAr: 'سيتاجليبتين', treatsAr: 'خافض لسكر الدم'),
  DrugReference(nameEn: 'Pioglitazone', nameAr: 'بيوجليتازون', treatsAr: 'خافض لسكر الدم، يحسن حساسية الأنسولين'),
  DrugReference(nameEn: 'Insulin', nameAr: 'أنسولين', treatsAr: 'منظم لسكر الدم بالحقن — السكري النوع الأول والثاني'),

  // ---- Respiratory ----
  DrugReference(nameEn: 'Salbutamol', nameAr: 'سالبوتامول', treatsAr: 'موسع للشعب الهوائية — الربو وضيق التنفس'),
  DrugReference(nameEn: 'Ventolin', nameAr: 'فينتولين', treatsAr: 'موسع للشعب الهوائية (سالبوتامول) — الربو'),
  DrugReference(nameEn: 'Budesonide', nameAr: 'بوديزونايد', treatsAr: 'كورتيزون استنشاقي — الربو المزمن'),
  DrugReference(nameEn: 'Montelukast', nameAr: 'مونتيلوكاست', treatsAr: 'مضاد للربو والحساسية التنفسية'),
  DrugReference(nameEn: 'Singulair', nameAr: 'سنجولير', treatsAr: 'مضاد للربو والحساسية (مونتيلوكاست)'),
  DrugReference(nameEn: 'Ambroxol', nameAr: 'أمبروكسول', treatsAr: 'مذيب للبلغم — السعال مع البلغم'),
  DrugReference(nameEn: 'Bromhexine', nameAr: 'بروميهيكسين', treatsAr: 'مذيب للبلغم — السعال'),
  DrugReference(nameEn: 'Guaifenesin', nameAr: 'غوايفينيسين', treatsAr: 'مذيب للبلغم والسعال'),
  DrugReference(nameEn: 'Dextromethorphan', nameAr: 'ديكستروميثورفان', treatsAr: 'مضاد للسعال الجاف'),

  // ---- Corticosteroids ----
  DrugReference(nameEn: 'Prednisolone', nameAr: 'بريدنيزولون', treatsAr: 'كورتيزون — التهابات والحساسية الشديدة'),
  DrugReference(nameEn: 'Dexamethasone', nameAr: 'ديكساميثازون', treatsAr: 'كورتيزون قوي — التهابات وحساسية شديدة'),
  DrugReference(nameEn: 'Hydrocortisone', nameAr: 'هيدروكورتيزون', treatsAr: 'كورتيزون خفيف — التهابات جلدية وحساسية'),
  DrugReference(nameEn: 'Betamethasone', nameAr: 'بيتاميثازون', treatsAr: 'كورتيزون موضعي — التهابات جلدية'),

  // ---- Vitamins / supplements ----
  DrugReference(nameEn: 'Vitamin C', nameAr: 'فيتامين سي', treatsAr: 'مقوي للمناعة ومضاد أكسدة'),
  DrugReference(nameEn: 'Vitamin D3', nameAr: 'فيتامين د٣', treatsAr: 'لصحة العظام ونقص فيتامين د'),
  DrugReference(nameEn: 'Vitamin B12', nameAr: 'فيتامين ب١٢', treatsAr: 'لنقص فيتامين ب١٢ وفقر الدم وتقوية الأعصاب'),
  DrugReference(nameEn: 'Folic Acid', nameAr: 'حمض الفوليك', treatsAr: 'مكمل للحوامل ولفقر الدم'),
  DrugReference(nameEn: 'Ferrous Sulfate (Iron)', nameAr: 'كبريتات الحديد', treatsAr: 'مكمل حديد — علاج فقر الدم الناتج عن نقص الحديد'),
  DrugReference(nameEn: 'Calcium Carbonate', nameAr: 'كربونات الكالسيوم', treatsAr: 'مكمل كالسيوم — صحة العظام ونقص الكالسيوم'),
  DrugReference(nameEn: 'Zinc', nameAr: 'زنك', treatsAr: 'مقوي للمناعة، يساعد بالتئام الجروح'),
  DrugReference(nameEn: 'Multivitamins', nameAr: 'فيتامينات متعددة', treatsAr: 'مكمل غذائي عام لسد النقص الغذائي'),

  // ---- Dermatological ----
  DrugReference(nameEn: 'Fusidic Acid', nameAr: 'فيوسيديك أسيد', treatsAr: 'مضاد حيوي موضعي — التهابات جلدية بكتيرية'),
  DrugReference(nameEn: 'Calamine Lotion', nameAr: 'لوشن كالامين', treatsAr: 'مهدئ للحكة والطفح الجلدي'),
  DrugReference(nameEn: 'Benzoyl Peroxide', nameAr: 'بنزويل بيروكسايد', treatsAr: 'علاج حب الشباب'),
  DrugReference(nameEn: 'Permethrin', nameAr: 'بيرميثرين', treatsAr: 'علاج الجرب والقمل'),

  // ---- Muscle / neuro ----
  DrugReference(nameEn: 'Orphenadrine', nameAr: 'أورفينادرين', treatsAr: 'مرخي للعضلات — تشنجات وآلام عضلية'),
  DrugReference(nameEn: 'Baclofen', nameAr: 'باكلوفين', treatsAr: 'مرخي للعضلات — تشنجات عضلية'),
  DrugReference(nameEn: 'Gabapentin', nameAr: 'غابابنتين', treatsAr: 'مسكن لآلام الأعصاب، يستخدم أيضاً للصرع'),
  DrugReference(nameEn: 'Pregabalin', nameAr: 'بريغابالين', treatsAr: 'مسكن لآلام الأعصاب والقلق'),
  DrugReference(nameEn: 'Amitriptyline', nameAr: 'أميتريبتيلين', treatsAr: 'مضاد اكتئاب، يستخدم أيضاً لآلام الأعصاب المزمنة'),

  // ---- Eye / ear ----
  DrugReference(nameEn: 'Chloramphenicol Eye Drops', nameAr: 'قطرة كلورامفينيكول', treatsAr: 'مضاد حيوي موضعي — التهابات العين'),
  DrugReference(nameEn: 'Tobramycin Eye Drops', nameAr: 'قطرة توبراميسين', treatsAr: 'مضاد حيوي موضعي — التهابات العين'),
  DrugReference(nameEn: 'Artificial Tears', nameAr: 'دموع صناعية', treatsAr: 'ترطيب العين — جفاف العين'),

  // ---- Thyroid ----
  DrugReference(nameEn: 'Levothyroxine', nameAr: 'ليفوثيروكسين', treatsAr: 'تعويض هرمون الغدة الدرقية — قصور الغدة الدرقية'),
  DrugReference(nameEn: 'Eltroxin', nameAr: 'إلتروكسين', treatsAr: 'تعويض هرمون الغدة الدرقية (ليفوثيروكسين)'),
  DrugReference(nameEn: 'Carbimazole', nameAr: 'كاربيمازول', treatsAr: 'علاج فرط نشاط الغدة الدرقية'),

  // ---- Urinary ----
  DrugReference(nameEn: 'Tamsulosin', nameAr: 'تامسولوسين', treatsAr: 'علاج تضخم البروستاتا وصعوبة التبول'),
  DrugReference(nameEn: 'Finasteride', nameAr: 'فيناسترايد', treatsAr: 'علاج تضخم البروستاتا وتساقط الشعر الوراثي'),

  // ---- Antiparasitics ----
  DrugReference(nameEn: 'Albendazole', nameAr: 'ألبيندازول', treatsAr: 'طارد للديدان والطفيليات المعوية'),
  DrugReference(nameEn: 'Mebendazole', nameAr: 'ميبيندازول', treatsAr: 'طارد للديدان المعوية'),

  // ---- Antiemetics ----
  DrugReference(nameEn: 'Ondansetron', nameAr: 'أوندانسيترون', treatsAr: 'مضاد قوي للغثيان والقيء'),

  // ---- Anxiety / sleep (controlled — pharmacist judgment required) ----
  DrugReference(nameEn: 'Diazepam', nameAr: 'ديازيبام', treatsAr: 'مهدئ ومضاد للقلق والتشنجات (دواء مسيطر عليه)'),
  DrugReference(nameEn: 'Sertraline', nameAr: 'سيرترالين', treatsAr: 'مضاد اكتئاب وقلق'),
  DrugReference(nameEn: 'Fluoxetine', nameAr: 'فلوكستين', treatsAr: 'مضاد اكتئاب وقلق'),

  // ---- Local anesthetic / dental ----
  DrugReference(nameEn: 'Lidocaine Gel', nameAr: 'جل ليدوكائين', treatsAr: 'مخدر موضعي — آلام الفم واللثة'),
];
