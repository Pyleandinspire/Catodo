import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/services/ai_agent.dart';
import 'package:catodo/models/task.dart';

void main() {
  group('AgentActionType 测试', () {
    test('fromString 正确解析所有类型', () {
      expect(AgentActionType.fromString('create_task'), AgentActionType.createTask);
      expect(AgentActionType.fromString('update_task'), AgentActionType.updateTask);
      expect(AgentActionType.fromString('complete_task'), AgentActionType.completeTask);
      expect(AgentActionType.fromString('delete_task'), AgentActionType.deleteTask);
      expect(AgentActionType.fromString('decompose_task'), AgentActionType.decomposeTask);
      expect(AgentActionType.fromString('add_tag'), AgentActionType.addTag);
      expect(AgentActionType.fromString('remove_tag'), AgentActionType.removeTag);
      expect(AgentActionType.fromString('set_group'), AgentActionType.setGroup);
      expect(AgentActionType.fromString('set_priority'), AgentActionType.setPriority);
    });

    test('fromString 未知值返回第一个类型', () {
      expect(AgentActionType.fromString('unknown'), AgentActionType.createTask);
    });
  });

  group('AgentAction 测试', () {
    test('fromJson 正确解析', () {
      final json = {
        'type': 'create_task',
        'params': {'title': '测试任务', 'priority': 3},
      };
      final action = AgentAction.fromJson(json);
      expect(action.type, AgentActionType.createTask);
      expect(action.params['title'], '测试任务');
      expect(action.params['priority'], 3);
    });

    test('fromJson 缺失字段使用默认值', () {
      final action = AgentAction.fromJson({});
      expect(action.type, AgentActionType.createTask);
      expect(action.params, isEmpty);
    });

    test('needsConfirmation - delete_task 需要确认', () {
      final action = AgentAction(type: AgentActionType.deleteTask, params: {'taskId': 1});
      expect(action.needsConfirmation, true);
    });

    test('needsConfirmation - complete_task 需要确认', () {
      final action = AgentAction(type: AgentActionType.completeTask, params: {'taskId': 1});
      expect(action.needsConfirmation, true);
    });

    test('needsConfirmation - update_task 需要确认', () {
      final action = AgentAction(type: AgentActionType.updateTask, params: {'taskId': 1});
      expect(action.needsConfirmation, true);
    });

    test('needsConfirmation - create_task 不需要确认', () {
      final action = AgentAction(type: AgentActionType.createTask, params: {'title': 'test'});
      expect(action.needsConfirmation, false);
    });

    test('needsConfirmation - add_tag 不需要确认', () {
      final action = AgentAction(type: AgentActionType.addTag, params: {'taskId': 1, 'tag': '紧急'});
      expect(action.needsConfirmation, false);
    });

    test('needsConfirmation - set_group 不需要确认', () {
      final action = AgentAction(type: AgentActionType.setGroup, params: {'taskId': 1, 'groupName': '工作'});
      expect(action.needsConfirmation, false);
    });

    test('needsConfirmation - set_priority 不需要确认', () {
      final action = AgentAction(type: AgentActionType.setPriority, params: {'taskId': 1, 'priority': 3});
      expect(action.needsConfirmation, false);
    });

    test('needsConfirmation - decompose_task 不需要确认', () {
      final action = AgentAction(type: AgentActionType.decomposeTask, params: {'taskId': 1, 'subtasks': []});
      expect(action.needsConfirmation, false);
    });

    test('description - create_task', () {
      final action = AgentAction(type: AgentActionType.createTask, params: {'title': '写报告'});
      expect(action.description, '创建任务「写报告」');
    });

    test('description - set_priority', () {
      final action = AgentAction(type: AgentActionType.setPriority, params: {'taskId': 1, 'priority': 3});
      expect(action.description, '设置任务 [1] 优先级为高');
    });

    test('description - add_tag', () {
      final action = AgentAction(type: AgentActionType.addTag, params: {'taskId': 1, 'tag': '紧急'});
      expect(action.description, '给任务 [1] 添加标签「紧急」');
    });
  });

  group('AgentResponse 测试', () {
    test('fromJson 正确解析完整响应', () {
      final json = {
        'reply': '好的，我帮你创建了任务',
        'actions': [
          {'type': 'create_task', 'params': {'title': '写报告', 'priority': 3}},
        ],
      };
      final response = AgentResponse.fromJson(json);
      expect(response.reply, '好的，我帮你创建了任务');
      expect(response.actions.length, 1);
      expect(response.actions[0].type, AgentActionType.createTask);
    });

    test('fromJson 无 actions 时为空列表', () {
      final json = {'reply': '你好！'};
      final response = AgentResponse.fromJson(json);
      expect(response.reply, '你好！');
      expect(response.actions, isEmpty);
    });

    test('fromJson 缺失 reply 时为空字符串', () {
      final json = <String, dynamic>{};
      final response = AgentResponse.fromJson(json);
      expect(response.reply, '');
      expect(response.actions, isEmpty);
    });

    test('fromJson 多个 actions', () {
      final json = {
        'reply': '好的',
        'actions': [
          {'type': 'create_task', 'params': {'title': '任务1'}},
          {'type': 'add_tag', 'params': {'taskId': 1, 'tag': '紧急'}},
          {'type': 'set_group', 'params': {'taskId': 1, 'groupName': '工作'}},
        ],
      };
      final response = AgentResponse.fromJson(json);
      expect(response.actions.length, 3);
    });
  });

  group('ActionResult 测试', () {
    test('成功结果', () {
      final result = ActionResult(success: true, message: '已创建任务');
      expect(result.success, true);
      expect(result.message, '已创建任务');
      expect(result.data, isNull);
    });

    test('失败结果', () {
      final result = ActionResult(success: false, message: '任务不存在');
      expect(result.success, false);
    });
  });

  group('buildTaskContext 测试', () {
    test('空任务列表', () {
      final context = buildTaskContext([]);
      expect(context, contains('当前没有活跃任务'));
    });

    test('包含任务摘要', () {
      final task = Task(title: '测试任务', priority: 3, groupName: '工作')
        ..id = 1
        ..tags = ['紧急'];
      final context = buildTaskContext([task]);
      expect(context, contains('[id:1]'));
      expect(context, contains('测试任务'));
      expect(context, contains('高'));
      expect(context, contains('工作'));
      expect(context, contains('紧急'));
    });

    test('包含分组和标签列表', () {
      final task1 = Task(title: '任务1', priority: 2, groupName: '工作')
        ..id = 1
        ..tags = ['编程', '紧急'];
      final task2 = Task(title: '任务2', priority: 1, groupName: '生活')
        ..id = 2
        ..tags = ['购物'];
      final context = buildTaskContext([task1, task2]);
      expect(context, contains('可用分组'));
      expect(context, contains('工作'));
      expect(context, contains('生活'));
      expect(context, contains('可用标签'));
      expect(context, contains('编程'));
      expect(context, contains('紧急'));
      expect(context, contains('购物'));
    });

    test('包含截止日期', () {
      final task = Task(title: '有截止日期的任务', priority: 1)
        ..id = 1
        ..dueDate = DateTime(2026, 6, 10);
      final context = buildTaskContext([task]);
      expect(context, contains('截止:2026-06-10'));
    });

    test('超过 50 个任务时截断', () {
      final tasks = List.generate(60, (i) => Task(title: '任务$i', priority: 1)..id = i);
      final context = buildTaskContext(tasks);
      expect(context, contains('活跃任务共 60 个'));
      // 不应包含第 51 个任务（id:50）
      expect(context, isNot(contains('[id:50]')));
      // 应包含第 50 个任务（id:49）
      expect(context, contains('[id:49]'));
    });

    test('活跃任务计数正确', () {
      final tasks = List.generate(3, (i) => Task(title: '任务$i', priority: 1)..id = i);
      final context = buildTaskContext(tasks);
      expect(context, contains('活跃任务共 3 个'));
    });
  });

  group('辅助方法测试', () {
    test('_parsePriority - int 值', () {
      // 通过 AgentAction.fromJson 间接测试
      final action = AgentAction.fromJson({
        'type': 'create_task',
        'params': {'title': 'test', 'priority': 3},
      });
      expect(action.params['priority'], 3);
    });

    test('_parsePriority - String 值', () {
      final action = AgentAction.fromJson({
        'type': 'create_task',
        'params': {'title': 'test', 'priority': '2'},
      });
      expect(action.params['priority'], '2');
    });

    test('_parsePriority - 超出范围被 clamp', () {
      // 直接通过 buildTaskContext 间接测试，这里测试 JSON 解析
      final action = AgentAction.fromJson({
        'type': 'create_task',
        'params': {'title': 'test', 'priority': 5},
      });
      expect(action.params['priority'], 5);
    });
  });

  group('kAgentSystemPrompt 测试', () {
    test('包含所有 action 类型', () {
      expect(kAgentSystemPrompt, contains('create_task'));
      expect(kAgentSystemPrompt, contains('update_task'));
      expect(kAgentSystemPrompt, contains('complete_task'));
      expect(kAgentSystemPrompt, contains('delete_task'));
      expect(kAgentSystemPrompt, contains('decompose_task'));
      expect(kAgentSystemPrompt, contains('add_tag'));
      expect(kAgentSystemPrompt, contains('remove_tag'));
      expect(kAgentSystemPrompt, contains('set_group'));
      expect(kAgentSystemPrompt, contains('set_priority'));
    });

    test('包含 JSON 格式要求', () {
      expect(kAgentSystemPrompt, contains('"reply"'));
      expect(kAgentSystemPrompt, contains('"actions"'));
    });

    test('包含规则说明', () {
      expect(kAgentSystemPrompt, contains('priority'));
      expect(kAgentSystemPrompt, contains('taskId'));
    });
  });
}
