# Quality Requirements

## Quality Goals

Ranked by importance, descending:

| Category | Quality | Description | Related Scenarios |
|----------|---------|-------------|-------------------|
| Maintainability |  | The project should be easy to maintain and evolve. Otherwise, as an unpaid side project, it is not sustainable | SC3 |
|                 | Testability | Changes should be easily verifiable, either locally or in CI | SC3, SC6 |
|                 | Updatability | The system, services and apps should be easy to update | SC2, SC13 |
| Security | | Wolkenschloss should be as secure as possible. The security is only limited by the security of the integrated applications, services and physical hardware | SC11, SC12 |
|          | Confidentiality | Data should be protected from unauthorized access, only the owners and allowed users should be able to access Wolkenschloss and its data | SC11, SC12 |
| Reliability | Maturity | The system should be stable and the apps and services should be mature projects with large communities | SC4, SC10 |
|             | Recoverability | After software and hardware failures, the system can be recovered | SC5 |
| Usability | Operability | The system, services and apps should be easy to operate and update for non-technical users. | SC1, SC2, SC7, SC10, SC12 |
|           | Accessibility | The system, services and apps should be accessible on most devices. | SC4, SC7, SC12 |
| Cost Efficiency | | Self hosting Wolkenschloss should not cost more than subscription based alternatives | SC9 |

## Quality Scenarios

| ID | Scenario |
|----|----------|
| SC1 | A user that can assemble a desktop PC can deploy Wolkenschloss on a machine without any further knowledge. |
| SC2 | A non-technical user can update Wolkenschloss without breaking it. |
| SC3 | A contributor can understand the architecture and codebase of Wolkenschloss quickly and be able to make changes confidently. |
| SC4 | A user can access the services and apps on a wide range of devices, including mobile phones and tablets. |
| SC5 | A user can recover from a failure with no data loss with the included backup system(s). |
| SC6 | Updating system dependencies, services and apps should be easy and quick for maintainers. |
| SC7 | A user does not have to choose services and apps. Instead, the maintainers curate a set of apps and services for the most common use cases. |
| SC8 | Technical users can customize and extend Wolkenschloss to their needs. |
| SC9 | A user can use a wide range of hardware, including older and less powerful devices to self host the project. |
| SC10 | The apps and services that come with Wolkenschloss (such as memories, personal file cloud, etc. ) are mature and have a good UX. |
| SC11 | The project and development follows best practices |
| SC12 | Wolkenschloss allows the owners to invite friends and family into the stack |
| SC13 | Self hosting is a complex task and Projekt Wolkenschloss reduces the complexity and time commitment for users significantly. |
