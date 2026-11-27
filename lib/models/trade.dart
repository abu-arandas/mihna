/// A group of skills on the checklist, such as brakes.
class SkillArea {
  const SkillArea({required this.code, required this.en, required this.ar, required this.skills});

  final String code;
  final String en;
  final String ar;
  final List<Skill> skills;

  String title(String language) => language == 'ar' ? ar : en;
}

/// One thing a trainee learns to do, and a supervisor signs off once they have watched it done.
class Skill {
  const Skill({required this.code, required this.en, required this.ar, this.safety = false});

  /// Stored in the database; never changes once a workshop uses it.
  final String code;
  final String en;
  final String ar;

  /// A skill about keeping people safe, shown with a safety mark.
  final bool safety;

  String title(String language) => language == 'ar' ? ar : en;
}

/// A trade's checklist. It is written here, in the app, rather than read from the database, so it is on the phone
/// before the first sync and the same in every workshop of the trade. A code, once used, is never reused.
class Trade {
  const Trade({required this.code, required this.en, required this.ar, required this.areas});

  final String code;
  final String en;
  final String ar;
  final List<SkillArea> areas;

  String title(String language) => language == 'ar' ? ar : en;

  Iterable<Skill> get skills => areas.expand((a) => a.skills);

  Skill? skill(String code) => skills.where((s) => s.code == code).firstOrNull;

  /// Every trade this build knows, by code.
  static const all = {'auto_repair': autoRepair};

  /// Light-vehicle repair, the pilot's trade: a first-year trainee in a small workshop in Amman. The list follows the
  /// jobs such a workshop does every week, safety first. A program partner reviews it before the pilot starts.
  static const autoRepair = Trade(
    code: 'auto_repair',
    en: 'Auto repair',
    ar: 'صيانة السيارات',
    areas: [
      SkillArea(
        code: 'safety',
        en: 'Workshop safety',
        ar: 'السلامة في الورشة',
        skills: [
          Skill(code: 'safety.ppe', en: 'Wears the right protective gear for the job', ar: 'يلبس معدات الوقاية المناسبة لكل شغلة', safety: true),
          Skill(code: 'safety.lift', en: 'Raises a car on a lift or jack stands safely', ar: 'يرفع السيارة على الرافعة أو الحمّالات بأمان', safety: true),
          Skill(
            code: 'safety.fluids',
            en: 'Handles and disposes of oil, coolant and brake fluid',
            ar: 'يتعامل مع الزيت وماء الرديتر وزيت البريك ويتخلّص منها صح',
            safety: true,
          ),
          Skill(code: 'safety.fire', en: 'Knows where the extinguisher is and how to use it', ar: 'يعرف مكان طفاية الحريق وطريقة استعمالها', safety: true),
        ],
      ),
      SkillArea(
        code: 'tools',
        en: 'Tools and measuring',
        ar: 'العُدّة والقياس',
        skills: [
          Skill(code: 'tools.torque', en: 'Tightens bolts to the specified torque', ar: 'يشدّ البراغي على العزم المطلوب'),
          Skill(
            code: 'tools.multimeter',
            en: 'Measures voltage, resistance and continuity with a multimeter',
            ar: 'يقيس الفولت والمقاومة والتوصيل بالملتيميتر',
          ),
          Skill(code: 'tools.manual', en: 'Finds a procedure and its specs in a service manual', ar: 'يلاقي طريقة الشغل ومواصفاتها بكتالوج الصيانة'),
          Skill(code: 'tools.care', en: 'Keeps tools clean, sorted and back in place', ar: 'يحافظ على العُدّة نظيفة ومرتّبة وبمكانها'),
        ],
      ),
      SkillArea(
        code: 'service',
        en: 'Routine service',
        ar: 'الصيانة الدورية',
        skills: [
          Skill(code: 'service.oil', en: 'Changes engine oil and filter', ar: 'يغيّر زيت المحرك والفلتر'),
          Skill(code: 'service.filters', en: 'Replaces air and cabin filters', ar: 'يغيّر فلتر الهوا وفلتر المكيّف'),
          Skill(code: 'service.fluids', en: 'Checks and tops up every fluid', ar: 'يفحص كل السوائل ويكمّلها'),
          Skill(code: 'service.plugs', en: 'Replaces spark plugs', ar: 'يغيّر البواجي'),
        ],
      ),
      SkillArea(
        code: 'brakes',
        en: 'Brakes',
        ar: 'الفرامل (البريك)',
        skills: [
          Skill(code: 'brakes.inspect', en: 'Inspects pads, discs and lines', ar: 'يفحص الفحمات والديسكات والبرابيش'),
          Skill(code: 'brakes.pads', en: 'Replaces brake pads', ar: 'يغيّر فحمات البريك'),
          Skill(code: 'brakes.discs', en: 'Replaces brake discs', ar: 'يغيّر ديسكات البريك'),
          Skill(code: 'brakes.bleed', en: 'Bleeds the brake system', ar: 'يفرّغ الهوا من نظام البريك', safety: true),
        ],
      ),
      SkillArea(
        code: 'wheels',
        en: 'Tyres, suspension and steering',
        ar: 'الكاوتشوك والتعليق والتوجيه',
        skills: [
          Skill(code: 'wheels.change', en: 'Removes and refits a wheel, nuts torqued in order', ar: 'يفك العجل ويركّبه ويشدّ الصواميل بالترتيب'),
          Skill(code: 'wheels.pressure', en: 'Checks tyre pressure, tread and wear pattern', ar: 'يفحص ضغط الكاوتشوك والنقشة وطريقة الاهتراء'),
          Skill(code: 'wheels.suspension', en: 'Inspects shocks, bushings and ball joints', ar: 'يفحص المساعدات والجلب والبيضات'),
          Skill(code: 'wheels.tierod', en: 'Replaces a tie rod end', ar: 'يغيّر راس الدركسيون'),
        ],
      ),
      SkillArea(
        code: 'engine',
        en: 'Engine and cooling',
        ar: 'المحرك والتبريد',
        skills: [
          Skill(code: 'engine.belt', en: 'Inspects and replaces an accessory belt', ar: 'يفحص سير الملحقات ويغيّره'),
          Skill(code: 'engine.coolant', en: 'Flushes and refills the cooling system', ar: 'يغسل نظام التبريد ويعبّيه من جديد'),
          Skill(code: 'engine.leaks', en: 'Finds the source of an oil or coolant leak', ar: 'يلاقي مصدر تسريب الزيت أو الماء'),
          Skill(code: 'engine.thermostat', en: 'Replaces a thermostat', ar: 'يغيّر البلف (الثرموستات)'),
        ],
      ),
      SkillArea(
        code: 'electrical',
        en: 'Electrical',
        ar: 'الكهرباء',
        skills: [
          Skill(code: 'electrical.battery', en: 'Tests and replaces a battery', ar: 'يفحص البطارية ويغيّرها'),
          Skill(code: 'electrical.charging', en: 'Tests the charging system', ar: 'يفحص نظام الشحن (الدينمو)'),
          Skill(code: 'electrical.lights', en: 'Repairs a lighting fault', ar: 'يصلّح عطل بالأضواء'),
          Skill(code: 'electrical.fuses', en: 'Traces a circuit and replaces fuses and relays', ar: 'يتتبّع الدارة ويغيّر الفيوزات والريليهات'),
        ],
      ),
      SkillArea(
        code: 'diagnostics',
        en: 'Diagnostics and the customer',
        ar: 'الفحص والزبون',
        skills: [
          Skill(code: 'diagnostics.obd', en: 'Reads and clears fault codes with an OBD scanner', ar: 'يقرأ الأعطال ويمسحها بجهاز الفحص (OBD)'),
          Skill(code: 'diagnostics.testdrive', en: 'Road-tests a car and describes what they found', ar: 'يجرّب السيارة بالطريق ويوصف شو لاحظ'),
          Skill(code: 'diagnostics.jobcard', en: 'Fills in a job card: fault, work done, parts', ar: 'يعبّي كرت الشغل: العطل والشغل والقطع'),
          Skill(code: 'diagnostics.explain', en: 'Explains the work done to a customer', ar: 'يشرح للزبون شو انعمل بسيارته'),
        ],
      ),
    ],
  );
}
